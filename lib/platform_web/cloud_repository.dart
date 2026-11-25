import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web/web.dart' as web;

import '../data/firestore_paths.dart';
import 'review_data.dart';

enum WebDataIssue { session, conflict, unavailable, invalid }

typedef CloudRow = ({String id, Map<String, dynamic> data});

class WebFinanceRepository {
  WebFinanceRepository(this.auth, this.store, this.uid);

  final FirebaseAuth auth;
  final FirebaseFirestore store;
  final String uid;
  bool _closed = false;

  bool get active =>
      !_closed &&
      auth.currentUser?.uid == uid &&
      auth.currentUser!.emailVerified;

  void close() => _closed = true;

  void check() {
    if (!active) throw WebDataIssue.session;
  }

  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      store.collection('${FirestorePaths.userRoot(uid)}/$name');

  String operationId() => _collection('webOperations').doc().id;

  Future<List<CloudRow>> list(String collection) async {
    check();
    final snapshot = await _collection(
      collection,
    ).limit(1001).get(const GetOptions(source: Source.server));
    check();
    if (snapshot.metadata.isFromCache ||
        snapshot.metadata.hasPendingWrites ||
        snapshot.size > 1000) {
      throw WebDataIssue.unavailable;
    }
    return [
      for (final doc in snapshot.docs)
        if (doc.data()['isDeleted'] != true) (id: doc.id, data: doc.data()),
    ];
  }

  Future<WebSnapshot> snapshot() async {
    final records = await Future.wait([
      for (final name in const [
        'transactions',
        'goals',
        'budgets',
        'investmentTheses',
        'portfolioHoldings',
        'webPreferences',
      ])
        list(name),
    ]);
    check();
    return WebSnapshot(
      records[0],
      records[1],
      records[2],
      records[3],
      records[4],
      records[5],
    );
  }

  Map<String, dynamic> _metadata(String id, Map<String, dynamic>? previous) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': id,
      'localId': previous?['localId'] ?? id,
      'createdAt': previous?['createdAt'] ?? now,
      'updatedAt': now,
      'version': (previous?['version'] ?? 0) + 1,
      'isSynced': true,
      'isDeleted': false,
      'syncStatus': 'synced',
    };
  }

  Future<void> _mutate(
    String operation,
    String target,
    Map<String, Object?> payload,
    Future<void> Function(Transaction txn) apply,
  ) async {
    check();
    if (!web.window.navigator.onLine) throw WebDataIssue.unavailable;
    final marker = _collection('webOperations').doc(operation);
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(payload)))
        .toString();
    WebDataIssue? issue;
    try {
      await store.runTransaction<void>((txn) async {
        issue = null;
        try {
          check();
          final old = await txn.get(marker);
          check();
          if (old.exists) {
            if (old.data()?['target'] != target ||
                old.data()?['fingerprint'] != fingerprint) {
              throw WebDataIssue.conflict;
            }
            return;
          }
          await apply(txn);
          check();
          txn.set(marker, {'target': target, 'fingerprint': fingerprint});
        } on WebDataIssue catch (error) {
          issue = error;
          rethrow;
        }
      });
    } catch (_) {
      // FlutterFire Web may wrap transaction callback failures in a JS error.
      if (issue != null) throw issue!;
      rethrow;
    }
    check();
  }

  Future<void> save(
    String collection,
    String operation,
    CloudRow? existing,
    Map<String, Object?> fields,
  ) {
    if (!const {
      'transactions',
      'goals',
      'budgets',
      'webPreferences',
      'webConversations',
    }.contains(collection)) {
      throw WebDataIssue.invalid;
    }
    final id =
        existing?.id ??
        switch (collection) {
          'webPreferences' => 'locale',
          'budgets' =>
            'web-${sha256.convert(utf8.encode(fields['category'] as String))}',
          _ => operation,
        };
    final ref = _collection(collection).doc(id);
    final expected = existing?.data['version'];
    return _mutate(
      operation,
      '$collection/$id',
      {'expected': expected, 'fields': fields},
      (txn) async {
        final current = (await txn.get(ref)).data();
        check();
        if ((existing == null && current != null) ||
            (existing != null &&
                (current == null ||
                    current['version'] != expected ||
                    current['isDeleted'] == true))) {
          throw WebDataIssue.conflict;
        }
        txn.set(ref, {...?current, ..._metadata(id, current), ...fields});
      },
    );
  }

  Future<void> contribute(String operation, CloudRow goal, int amount) {
    if (amount <= 0) throw WebDataIssue.invalid;
    final parent = _collection('goals').doc(goal.id);
    final child = parent.collection('contributions').doc(operation);
    return _mutate(
      operation,
      'goals/${goal.id}/contributions/$operation',
      {'amount': amount},
      (txn) async {
        final current = (await txn.get(parent)).data();
        final contribution = await txn.get(child);
        check();
        if (current == null ||
            current['isDeleted'] == true ||
            contribution.exists) {
          throw WebDataIssue.conflict;
        }
        txn.set(child, {
          ..._metadata(operation, null),
          'goalId': goal.id,
          'amount': amount,
          'contributedAt': DateTime.now().toUtc().toIso8601String(),
          'note': '',
        });
        txn.set(parent, {
          ...current,
          ..._metadata(goal.id, current),
          'saved': (current['saved'] as int) + amount,
        });
      },
    );
  }
}

class WebSnapshot implements WorkspaceData {
  WebSnapshot(
    this.transactionRows,
    this.goalRows,
    this.budgetRows,
    this.thesisRows,
    this.holdingRows,
    this.preferenceRows,
  );

  final List<CloudRow> transactionRows;
  final List<CloudRow> goalRows;
  final List<CloudRow> budgetRows;
  final List<CloudRow> thesisRows;
  final List<CloudRow> holdingRows;
  final List<CloudRow> preferenceRows;

  int _signed(CloudRow row) =>
      (row.data['amount'] as int) * (row.data['isIncome'] == true ? 1 : -1);

  @override
  int get balance =>
      transactionRows.fold(0, (total, row) => total + _signed(row));

  Map<String, int> get spending {
    final now = DateTime.now();
    final totals = <String, int>{};
    for (final row in transactionRows) {
      final occurred = DateTime.parse(
        row.data['occurredAt'] as String,
      ).toLocal();
      if (_signed(row) >= 0 ||
          occurred.year != now.year ||
          occurred.month != now.month) {
        continue;
      }
      final category = row.data['category'] as String;
      totals.update(
        category,
        (value) => value - _signed(row),
        ifAbsent: () => -_signed(row),
      );
    }
    return totals;
  }

  @override
  int get monthlySpending =>
      spending.values.fold(0, (total, item) => total + item);

  @override
  int get budget => budgetRows.fold(
    0,
    (total, row) => total + (row.data['monthlyLimit'] as int),
  );

  @override
  List<({String name, int saved, int target})> get goals => [
    for (final row in goalRows)
      (
        name: row.data['name'] as String,
        saved: row.data['saved'] as int,
        target: row.data['target'] as int,
      ),
  ];

  @override
  List<({String merchant, String category, int amount})> get transactions {
    final rows = transactionRows.toList()
      ..sort(
        (a, b) => DateTime.parse(
          b.data['occurredAt'] as String,
        ).compareTo(DateTime.parse(a.data['occurredAt'] as String)),
      );
    return [
      for (final row in rows.take(5))
        (
          merchant: row.data['merchant'] as String,
          category: row.data['category'] as String,
          amount: _signed(row),
        ),
    ];
  }

  @override
  List<({String symbol, String name, int price, double change})> get quotes =>
      const [];
}
