import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as paths;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

import 'investment_models.dart';
import '../../ai/models.dart';

class FinanceTransaction {
  const FinanceTransaction({
    this.id,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.merchant,
    required this.occurredAt,
    this.note = '',
    this.source = 'Manual entry',
  });

  final int? id;
  final int amount;
  final bool isIncome;
  final String category;
  final String merchant;
  final DateTime occurredAt;
  final String note;
  final String source;

  factory FinanceTransaction.fromMap(Map<String, Object?> map) =>
      FinanceTransaction(
        id: map['id'] as int,
        amount: map['amount'] as int,
        isIncome: (map['is_income'] as int) == 1,
        category: map['category'] as String,
        merchant: map['merchant'] as String,
        occurredAt: DateTime.parse(map['occurred_at'] as String),
        note: map['note'] as String? ?? '',
        source: map['source'] as String? ?? 'Manual entry',
      );

  Map<String, Object?> toMap() => {
    'amount': amount,
    'is_income': isIncome ? 1 : 0,
    'category': category,
    'merchant': merchant,
    'occurred_at': occurredAt.toIso8601String(),
    'note': note,
    'source': source,
  };
}

class SavingsGoal {
  const SavingsGoal({
    this.id,
    required this.name,
    required this.target,
    required this.saved,
    required this.deadline,
    required this.purpose,
  });

  final int? id;
  final String name;
  final int target;
  final int saved;
  final DateTime deadline;
  final String purpose;

  int get remaining => (target - saved).clamp(0, target).toInt();
  int get progressPercent => target <= 0
      ? 0
      : ((saved * 100 + target ~/ 2) ~/ target).clamp(0, 100).toInt();

  factory SavingsGoal.fromMap(Map<String, Object?> map) => SavingsGoal(
    id: map['id'] as int,
    name: map['name'] as String,
    target: map['target'] as int,
    saved: map['saved'] as int,
    deadline: DateTime.parse(map['deadline'] as String),
    purpose: map['purpose'] as String,
  );

  Map<String, Object?> toMap() => {
    'name': name,
    'target': target,
    'saved': saved,
    'deadline': deadline.toIso8601String(),
    'purpose': purpose,
  };
}

class DepositProduct {
  const DepositProduct({
    required this.id,
    required this.bank,
    required this.product,
    required this.termMonths,
    required this.effectiveRateBps,
    required this.nominalRateBps,
    required this.topUp,
    required this.withdrawal,
    required this.capitalization,
    required this.source,
  });

  final int id;
  final String bank;
  final String product;
  final int termMonths;
  final int effectiveRateBps;
  final int nominalRateBps;
  final bool topUp;
  final bool withdrawal;
  final bool capitalization;
  final String source;

  factory DepositProduct.fromMap(Map<String, Object?> map) => DepositProduct(
    id: map['id'] as int,
    bank: map['bank'] as String,
    product: map['product'] as String,
    termMonths: map['term_months'] as int,
    effectiveRateBps: map['effective_rate_bps'] as int,
    nominalRateBps: map['nominal_rate_bps'] as int,
    topUp: (map['top_up'] as int) == 1,
    withdrawal: (map['withdrawal'] as int) == 1,
    capitalization: (map['capitalization'] as int) == 1,
    source: map['source'] as String,
  );
}

class FinanceRepository {
  FinanceRepository._(this._db, this._currentUid, this._accountUid);
  final String? _accountUid;
  final Database _db;
  final String? Function() _currentUid;

  static const _secureStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static bool _mobileFactoryInitialized = false;
  static final _mobileOpens = <String, Future<void>>{};

  static bool get _usesSqlCipher =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  static Future<FinanceRepository> openForAccount(String uid, {String? directory}) async {
    if (uid.isEmpty) throw ArgumentError('An account UID is required');
    final account = base64Url.encode(utf8.encode(uid));
    if (_usesSqlCipher && !_mobileFactoryInitialized) {
      databaseFactory = cipher.databaseFactory;
      _mobileFactoryInitialized = true;
    }
    final databaseDirectory = directory ?? await getDatabasesPath();
    final original = paths.join(databaseDirectory, 'smartsave_account_$account.db');
    if (!_usesSqlCipher) {
      return open(databasePath: original, currentUid: () => uid, accountUid: uid,
        singleInstance: false);
    }

    // Serialize reads, key creation and migration for the same database path.
    final prior = _mobileOpens[original];
    final opening = _openEncryptedAccount(uid, account, original, prior);
    final completion = opening.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _mobileOpens[original] = completion;
    try {
      return await opening;
    } finally {
      if (identical(_mobileOpens[original], completion)) _mobileOpens.remove(original);
    }
  }

  static Future<FinanceRepository> _openEncryptedAccount(
    String uid, String account, String original, Future<void>? prior,
  ) async {
    if (prior != null) await prior;
    final encrypted = '${paths.withoutExtension(original)}.encrypted.db';
    final keyName = 'smartsave.sqlite.v1.$account';
    FinanceRepository? repository;
    try {
      var key = await _secureStorage.read(key: keyName);
      if (key == null) {
        if (await databaseExists(encrypted)) {
          throw StateError('The encrypted database key is unavailable.');
        }
        final random = Random.secure();
        key = base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256)));
        await _secureStorage.write(key: keyName, value: key);
        if (await _secureStorage.read(key: keyName) != key) {
          throw StateError('The database key could not be persisted.');
        }
      }
      final hasOriginal = await databaseExists(original);
      repository = await open(databasePath: encrypted, currentUid: () => uid,
        accountUid: uid, singleInstance: false, password: key, seed: !hasOriginal);
      if (hasOriginal) await repository._copyPlaintextAccount(original);
      return repository;
    } catch (_) {
      try {
        await repository?.close();
      } catch (_) {
        // Retain both files and the key even if closing failed.
      }
      throw StateError('Could not open or migrate the protected account database. Original files were kept.');
    }
  }

  Future<void> _copyPlaintextAccount(String original) async {
    const marker = 'account_sqlcipher_migration_complete';
    final marked = await _db.query('preferences', where: 'key IN (?, ?)',
      whereArgs: [marker, 'account_deletion_prepared']);
    if (marked.isNotEmpty) return;
    final source = await openReadOnlyDatabase(original, singleInstance: false);
    try {
      final integrity = await source.rawQuery('PRAGMA quick_check');
      if (integrity.length != 1 || integrity.single.values.single != 'ok') {
        throw StateError('Original account database failed integrity verification.');
      }
      final sourceTables = await _tableNames(source);
      final tables = [..._portableTables.keys, 'deposit_products', 'preferences', 'sync_operations'];
      if (sourceTables.any((table) => !table.startsWith('sqlite_') && !tables.contains(table))) {
        throw StateError('Original account database contains unsupported tables.');
      }
      await _db.transaction((txn) async {
        for (final table in tables.where(sourceTables.contains)) {
          final rows = await source.query(table);
          if ((await txn.query(table, limit: 1)).isNotEmpty) {
            throw StateError('The migration destination already contains records.');
          }
          final batch = txn.batch();
          for (final row in rows) {
            batch.insert(table, row);
          }
          await batch.commit(noResult: true);
          final key = _portableTables[table] ?? (table == 'preferences' ? 'key' : 'id');
          final copied = {
            for (final row in await txn.query(table)) row[key]: row,
          };
          if (copied.length != rows.length ||
              rows.any((row) {
                final copy = copied[row[key]];
                return copy == null ||
                    row.entries.any((field) => copy[field.key] != field.value);
              })) {
            throw StateError('Migration did not preserve the original rows.');
          }
        }
        if (sourceTables.contains('sqlite_sequence')) {
          for (final row in await source.query('sqlite_sequence')) {
            await txn.delete('sqlite_sequence', where: 'name = ?', whereArgs: [row['name']]);
            await txn.insert('sqlite_sequence', row);
          }
        }
        if ((await txn.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
          throw StateError('Migrated records failed foreign-key verification.');
        }
        await txn.insert('preferences', {'key': marker, 'value': '1'});
      });
    } finally {
      await source.close();
    }
  }

  static Future<FinanceRepository> open({
    String? databasePath,
    String? Function()? currentUid,
    bool singleInstance = true,
    String? accountUid,
    String? password,
    bool seed = true,
  }) async {
    final path =
        databasePath ??
        paths.join(await getDatabasesPath(), 'smartsave_demo.db');
    final db = await databaseFactory.openDatabase(
      path,
      options: cipher.SqlCipherOpenDatabaseOptions(
      password: password,
      version: 3,
      singleInstance: singleInstance,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount INTEGER NOT NULL CHECK(amount > 0),
          is_income INTEGER NOT NULL CHECK(is_income IN (0,1)),
          category TEXT NOT NULL,
          merchant TEXT NOT NULL,
          occurred_at TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          source TEXT NOT NULL DEFAULT 'Manual entry'
        )''');
        await db.execute('''CREATE TABLE goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          target INTEGER NOT NULL CHECK(target > 0),
          saved INTEGER NOT NULL DEFAULT 0 CHECK(saved >= 0),
          deadline TEXT NOT NULL,
          purpose TEXT NOT NULL
        )''');
        await db.execute('''CREATE TABLE goal_contributions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          goal_id INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
          amount INTEGER NOT NULL CHECK(amount > 0),
          contributed_at TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT ''
        )''');
        await db.execute('''CREATE TABLE budgets (
          category TEXT PRIMARY KEY,
          monthly_limit INTEGER NOT NULL CHECK(monthly_limit >= 0)
        )''');
        await db.execute('''CREATE TABLE preferences (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )''');
        await db.execute('''CREATE TABLE advice (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          kind TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          source TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'Viewed',
          created_at TEXT NOT NULL
        )''');
        await db.execute('''CREATE TABLE watchlist (
          ticker TEXT PRIMARY KEY,
          added_at TEXT NOT NULL
        )''');
        await db.execute('''CREATE TABLE deposit_products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bank TEXT NOT NULL,
          product TEXT NOT NULL,
          term_months INTEGER NOT NULL,
          effective_rate_bps INTEGER NOT NULL,
          nominal_rate_bps INTEGER NOT NULL,
          top_up INTEGER NOT NULL,
          withdrawal INTEGER NOT NULL,
          capitalization INTEGER NOT NULL,
          source TEXT NOT NULL
        )''');
        await _createInvestmentTables(db);
        await _createAIMessagesTable(db);
        if (seed) await _seed(db);
        await _ensureSyncColumns(db);
        if (seed && accountUid != null) {
          await db.insert('preferences', {
            'key': _seedSnapshotKey,
            'value': await _seedSnapshot(db),
          });
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createInvestmentTables(db);
        if (oldVersion < 3) await _createAIMessagesTable(db);
        await _ensureSyncColumns(db);
      },
      onConfigure: (db) async {
        if (password != null) {
          final version = await db.rawQuery('PRAGMA cipher_version');
          if (version.isEmpty) throw StateError('SQLCipher is unavailable.');
          await db.rawQuery('SELECT count(*) FROM sqlite_master');
        }
        await db.execute('PRAGMA foreign_keys = ON');
      },
    ));
    // Ensure sync columns exist for existing databases (version bump doesn't
    // trigger onCreate/onUpgrade when version is unchanged).
    await _ensureSyncColumns(db);
    return FinanceRepository._(db, currentUid ?? () => null, accountUid);
  }

  static Future<void> _createInvestmentTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE investment_theses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      security_name TEXT NOT NULL,
      ticker TEXT NOT NULL,
      exchange TEXT NOT NULL DEFAULT 'KASE',
      identifier TEXT NOT NULL DEFAULT '',
      rationale TEXT NOT NULL DEFAULT '',
      horizon TEXT NOT NULL DEFAULT '',
      assumptions TEXT NOT NULL DEFAULT '',
      risks TEXT NOT NULL DEFAULT '',
      invalidation_conditions TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE thesis_conditions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      thesis_id INTEGER NOT NULL REFERENCES investment_theses(id) ON DELETE CASCADE,
      description TEXT NOT NULL,
      metric TEXT NOT NULL DEFAULT '',
      comparator TEXT NOT NULL DEFAULT 'atLeast',
      threshold REAL,
      observed_value REAL,
      reporting_period TEXT NOT NULL DEFAULT '',
      source TEXT NOT NULL DEFAULT '',
      evidence_note TEXT NOT NULL DEFAULT ''
    )''');
    await db.execute('''CREATE TABLE thesis_assessments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      thesis_id INTEGER NOT NULL REFERENCES investment_theses(id) ON DELETE CASCADE,
      assessed_at TEXT NOT NULL,
      payload_json TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE portfolio_holdings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      security_name TEXT NOT NULL,
      ticker TEXT NOT NULL,
      exchange TEXT NOT NULL DEFAULT 'KASE',
      identifier TEXT NOT NULL DEFAULT '',
      market_value_kzt INTEGER NOT NULL CHECK(market_value_kzt >= 0),
      fx_sensitivity REAL,
      oil_sensitivity REAL,
      rate_sensitivity REAL
    )''');
    await db.execute('''CREATE TABLE investment_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )''');
  }

  static Future<void> _createAIMessagesTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE ai_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      is_streaming INTEGER NOT NULL DEFAULT 0,
      error TEXT
    )''');
  }

  static Future<void> _seed(DatabaseExecutor db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final seedTransactions = <FinanceTransaction>[
      FinanceTransaction(
        amount: 18400,
        isIncome: false,
        category: 'Food',
        merchant: 'Grocery store',
        occurredAt: today.add(const Duration(hours: 13, minutes: 20)),
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 2100,
        isIncome: false,
        category: 'Transport',
        merchant: 'Taxi',
        occurredAt: today.add(const Duration(hours: 9, minutes: 5)),
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 420000,
        isIncome: true,
        category: 'Income',
        merchant: 'Salary',
        occurredAt: today.add(const Duration(hours: 8)),
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 1800,
        isIncome: false,
        category: 'Food',
        merchant: 'Coffee shop',
        occurredAt: today
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 17, minutes: 40)),
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 6300,
        isIncome: false,
        category: 'Health',
        merchant: 'Pharmacy',
        occurredAt: today
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 12, minutes: 15)),
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 24900,
        isIncome: false,
        category: 'Shopping',
        merchant: 'Online store',
        occurredAt: today
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 10, minutes: 30)),
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 21000,
        isIncome: false,
        category: 'Food',
        merchant: 'Food delivery',
        occurredAt: today.subtract(const Duration(days: 2)),
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 64800,
        isIncome: false,
        category: 'Food',
        merchant: 'Market and groceries',
        occurredAt: today.subtract(const Duration(days: 4)),
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 44100,
        isIncome: false,
        category: 'Shopping',
        merchant: 'Clothing store',
        occurredAt: today.subtract(const Duration(days: 5)),
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 53900,
        isIncome: false,
        category: 'Transport',
        merchant: 'Transit and rides',
        occurredAt: today.subtract(const Duration(days: 6)),
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 50000,
        isIncome: false,
        category: 'Bills',
        merchant: 'Utilities',
        occurredAt: today.subtract(const Duration(days: 7)),
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 25100,
        isIncome: false,
        category: 'Other',
        merchant: 'Other spending',
        occurredAt: today.subtract(const Duration(days: 8)),
        source: 'Sample data',
      ),
    ];
    for (final item in seedTransactions) {
      await db.insert('transactions', item.toMap());
    }
    final previousMonth = DateTime(now.year, now.month - 1, 15, 12);
    final previousTransactions = [
      FinanceTransaction(
        amount: 94643,
        isIncome: false,
        category: 'Food',
        merchant: 'Previous month food',
        occurredAt: previousMonth,
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 66990,
        isIncome: false,
        category: 'Shopping',
        merchant: 'Previous month shopping',
        occurredAt: previousMonth,
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 58333,
        isIncome: false,
        category: 'Transport',
        merchant: 'Previous month transport',
        occurredAt: previousMonth,
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 50000,
        isIncome: false,
        category: 'Bills',
        merchant: 'Previous month bills',
        occurredAt: previousMonth,
        source: 'Sample data',
      ),
      FinanceTransaction(
        amount: 31400,
        isIncome: false,
        category: 'Other',
        merchant: 'Previous month other',
        occurredAt: previousMonth,
        source: 'Sample data',
      ),
    ];
    for (final item in previousTransactions) {
      await db.insert('transactions', item.toMap());
    }
    final goals = [
      SavingsGoal(
        name: 'New laptop',
        target: 240000,
        saved: 148000,
        deadline: DateTime(now.year, now.month + 4, 1),
        purpose: 'Purchase',
      ),
      SavingsGoal(
        name: 'Emergency fund',
        target: 500000,
        saved: 175000,
        deadline: DateTime(now.year, now.month + 12, 1),
        purpose: 'Safety cushion',
      ),
      SavingsGoal(
        name: 'Trip',
        target: 300000,
        saved: 30000,
        deadline: DateTime(now.year, now.month + 8, 1),
        purpose: 'Travel',
      ),
    ];
    for (final goal in goals) {
      final id = await db.insert('goals', goal.toMap());
      await db.insert('goal_contributions', {
        'goal_id': id,
        'amount': goal.saved,
        'contributed_at': now.toIso8601String(),
        'note': 'Fictional demo starting balance',
      });
    }
    const limits = {
      'Food': 95000,
      'Shopping': 70000,
      'Transport': 60000,
      'Bills': 60000,
      'Health': 30000,
      'Other': 40000,
    };
    for (final entry in limits.entries) {
      await db.insert('budgets', {
        'category': entry.key,
        'monthly_limit': entry.value,
      });
    }
    await db.insert('preferences', {
      'key': 'opening_balance',
      'value': '1442266',
    });
    const adviceRows = [
      [
        'Savings',
        'Cut food delivery by 15 000 ₸',
        'Sample estimate based on local demo spending.',
        'Sample spending',
      ],
      [
        'Deposit',
        'Freedom Bank · 19.50% ГЭСВ',
        'Indicative rate-card sample; verify directly with the bank.',
        'Sample rate cards',
      ],
      [
        'Stock',
        'Halyk Bank (HSBK) fits Moderate',
        'Fictional watchlist context; not investment advice.',
        'Sample KASE data',
      ],
    ];
    for (final row in adviceRows) {
      await db.insert('advice', {
        'kind': row[0],
        'title': row[1],
        'body': row[2],
        'source': row[3],
        'created_at': now.toIso8601String(),
      });
    }
    const products = [
      [
        'Freedom Bank',
        'Стратегия',
        3,
        1950,
        1791,
        0,
        0,
        0,
        'Fictional prototype rate-card sample',
      ],
      [
        'Bereke Bank',
        'Bereke+',
        3,
        1950,
        1791,
        1,
        0,
        0,
        'Fictional prototype rate-card sample',
      ],
      [
        'Kaspi.kz',
        'Накопительный',
        3,
        1900,
        1752,
        1,
        1,
        0,
        'Fictional prototype rate-card sample',
      ],
      [
        'Eurasian Bank',
        'TURBO',
        3,
        1900,
        1767,
        1,
        0,
        1,
        'Fictional prototype rate-card sample',
      ],
      [
        'Bank CenterCredit',
        'Моя цель',
        6,
        1886,
        1740,
        1,
        0,
        1,
        'Fictional prototype rate-card sample',
      ],
      [
        'Bank RBK',
        'Grand',
        6,
        1600,
        1490,
        0,
        0,
        1,
        'Fictional prototype rate-card sample',
      ],
    ];
    for (final row in products) {
      await db.insert('deposit_products', {
        'bank': row[0],
        'product': row[1],
        'term_months': row[2],
        'effective_rate_bps': row[3],
        'nominal_rate_bps': row[4],
        'top_up': row[5],
        'withdrawal': row[6],
        'capitalization': row[7],
        'source': row[8],
      });
    }
  }

  Future<List<FinanceTransaction>> transactions({
    String? category,
    String? query,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (category != null && category != 'All') {
      clauses.add('category = ?');
      args.add(category);
    }
    if (query != null && query.trim().isNotEmpty) {
      clauses.add('(merchant LIKE ? OR note LIKE ?)');
      args.addAll(['%${query.trim()}%', '%${query.trim()}%']);
    }
    final rows = await _db.query(
      'transactions',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'occurred_at DESC',
    );
    return rows.map(FinanceTransaction.fromMap).toList();
  }

  Future<int> saveTransaction(FinanceTransaction transaction) async {
    if (transaction.amount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    final values = Map<String, Object?>.from(transaction.toMap());
    // When updating an existing record, mark it as no longer synced so it is
    // re-uploaded on the next push. Keep cloud_id so conflict detection can
    // still find the matching remote record. Do not touch the id column.
    if (transaction.id != null) {
      values['is_synced'] = 0;
      values['synced_at'] = null;
    }
    final id = transaction.id == null
        ? await _db.insert('transactions', values)
        : (await _db.update(
            'transactions',
            values,
            where: 'id = ?',
            whereArgs: [transaction.id],
          )).toDouble().toInt();
    await _recordSyncOp(
      entityType: 'transaction',
      entityId: id.toString(),
      operation: transaction.id == null ? 'create' : 'update',
      payload: values,
    );
    return id;
  }

  Future<void> deleteTransaction(int id) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      await _recordSyncOp(
        executor: txn,
        entityType: 'transaction',
        entityId: id.toString(),
        operation: 'delete',
        payload: rows.first,
      );
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<SavingsGoal>> goals() async {
    final rows = await _db.query('goals', orderBy: 'deadline ASC');
    return rows.map(SavingsGoal.fromMap).toList();
  }

  Future<int> saveGoal(SavingsGoal goal) async {
    if (goal.name.trim().isEmpty || goal.target <= 0) {
      throw ArgumentError('Enter a goal name and a positive target.');
    }
    final id = goal.id == null
        ? await _db.insert('goals', goal.toMap())
        : (await _db.update(
            'goals',
            goal.toMap(),
            where: 'id = ?',
            whereArgs: [goal.id],
          )).toDouble().toInt();
    await _recordSyncOp(
      entityType: 'goal',
      entityId: id.toString(),
      operation: goal.id == null ? 'create' : 'update',
      payload: goal.toMap(),
    );
    return id;
  }

  Future<void> deleteGoal(int id) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'goals',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      await _recordSyncOp(
        executor: txn,
        entityType: 'goal',
        entityId: id.toString(),
        operation: 'delete',
        payload: rows.first,
      );
      await txn.delete(
        'goal_contributions',
        where: 'goal_id = ?',
        whereArgs: [id],
      );
      await txn.delete('goals', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> addContribution(int goalId, int amount) async {
    if (amount <= 0) {
      throw ArgumentError('Contribution must be greater than zero.');
    }
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'goals',
        where: 'id = ?',
        whereArgs: [goalId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Goal no longer exists.');
      final goal = SavingsGoal.fromMap(rows.first);
      await txn.insert('goal_contributions', {
        'goal_id': goalId,
        'amount': amount,
        'contributed_at': DateTime.now().toIso8601String(),
        'note': 'Manual demo contribution',
      });
      await txn.update(
        'goals',
        {'saved': goal.saved + amount},
        where: 'id = ?',
        whereArgs: [goalId],
      );
    });
  }

  Future<Map<String, int>> spendingByCategory({DateTime? month}) async {
    final date = month ?? DateTime.now();
    final start = DateTime(date.year, date.month);
    final end = DateTime(date.year, date.month + 1);
    final rows = await _db.rawQuery(
      '''SELECT category, SUM(amount) AS total FROM transactions
      WHERE is_income = 0 AND occurred_at >= ? AND occurred_at < ? GROUP BY category''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return {
      for (final row in rows)
        row['category'] as String: (row['total'] as num).toInt(),
    };
  }

  Future<Map<String, int>> spendingChangePercent({DateTime? month}) async {
    final currentMonth = month ?? DateTime.now();
    final current = await spendingByCategory(month: currentMonth);
    final previous = await spendingByCategory(
      month: DateTime(currentMonth.year, currentMonth.month - 1),
    );
    final categories = {...current.keys, ...previous.keys};
    return {
      for (final category in categories)
        if ((previous[category] ?? 0) > 0)
          category: _roundedPercentChange(
            current[category] ?? 0,
            previous[category]!,
          ),
    };
  }

  Future<int> spentThisMonth() async => (await spendingByCategory()).values
      .fold<int>(0, (sum, amount) => sum + amount);

  Future<int> totalBalance() async {
    final baseRows = await _db.query(
      'preferences',
      where: 'key = ?',
      whereArgs: ['opening_balance'],
      limit: 1,
    );
    final opening = baseRows.isEmpty
        ? 0
        : int.tryParse(baseRows.first['value'] as String) ?? 0;
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(CASE WHEN is_income=1 THEN amount ELSE -amount END),0) AS net FROM transactions',
    );
    return opening + (rows.first['net'] as num).toInt();
  }

  Future<Map<String, int>> budgets() async {
    final rows = await _db.query('budgets');
    return {
      for (final row in rows)
        row['category'] as String: row['monthly_limit'] as int,
    };
  }

  Future<void> saveBudget(String category, int limit) async {
    if (limit < 0) throw ArgumentError('Budget cannot be negative.');
    await _db.insert('budgets', {
      'category': category,
      'monthly_limit': limit,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _recordSyncOp(
      entityType: 'budget',
      entityId: category,
      operation: 'create',
      payload: {'category': category, 'monthly_limit': limit},
    );
  }

  Future<List<DepositProduct>> deposits({
    int? term,
    bool? topUp,
    bool? withdrawal,
    bool? capitalization,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (term != null) {
      clauses.add('term_months = ?');
      args.add(term);
    }
    if (topUp == true) clauses.add('top_up = 1');
    if (withdrawal == true) clauses.add('withdrawal = 1');
    if (capitalization == true) clauses.add('capitalization = 1');
    final rows = await _db.query(
      'deposit_products',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'effective_rate_bps DESC',
    );
    return rows.map(DepositProduct.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> adviceHistory() =>
      _db.query('advice', orderBy: 'created_at DESC');

  Future<bool> isWatched(String ticker) async => (await _db.query(
    'watchlist',
    where: 'ticker = ?',
    whereArgs: [ticker],
    limit: 1,
  )).isNotEmpty;

  Future<void> toggleWatch(String ticker) async {
    if (await isWatched(ticker)) {
      await _db.delete('watchlist', where: 'ticker = ?', whereArgs: [ticker]);
    } else {
      await _db.insert('watchlist', {
        'ticker': ticker,
        'added_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<InvestmentThesis>> investmentTheses() async {
    final rows = await _db.query(
      'investment_theses',
      where: 'local_deleted = 0',
      orderBy: 'updated_at DESC',
    );
    return rows.map(InvestmentThesis.fromMap).toList();
  }

  Future<int> saveInvestmentThesis(InvestmentThesis thesis) async {
    if (thesis.securityName.trim().isEmpty || thesis.ticker.trim().isEmpty) {
      throw ArgumentError('Enter a security name and ticker.');
    }
    return _db.transaction((txn) async {
      final values = {...thesis.toMap(), 'is_synced': 0};
      final id = thesis.id;
      final savedId = id ?? await txn.insert('investment_theses', {...values, 'cloud_id': _newCloudId()});
      if (id != null) {
        final changed = await txn.update('investment_theses', values,
          where: 'id = ? AND local_deleted = 0', whereArgs: [id]);
        if (changed != 1) throw StateError('The record is no longer available.');
      }
      await _recordSyncOp(
        executor: txn,
        entityType: 'investment_thesis',
        entityId: savedId.toString(),
        operation: id == null ? 'create' : 'update',
        payload: thesis.toMap(),
      );
      return savedId;
    });
  }

  Future<List<ThesisCondition>> thesisConditions(int thesisId) async {
    final rows = await _db.query(
      'thesis_conditions',
      where: 'thesis_id = ?',
      whereArgs: [thesisId],
      orderBy: 'id',
    );
    return rows.map(ThesisCondition.fromMap).toList();
  }

  Future<int> saveThesisCondition(ThesisCondition condition) async {
    if (condition.description.trim().isEmpty) {
      throw ArgumentError('Enter a condition description.');
    }
    if (condition.id == null) {
      return _db.insert('thesis_conditions', condition.toMap());
    }
    await _db.update(
      'thesis_conditions',
      condition.toMap(),
      where: 'id = ?',
      whereArgs: [condition.id],
    );
    return condition.id!;
  }

  Future<void> deleteInvestmentThesis(int thesisId) =>
      _deleteInvestmentRecord('investment_theses', 'investment_thesis', thesisId);

  Future<int> saveThesisAssessment(ThesisAssessment assessment) =>
      _db.insert('thesis_assessments', assessment.toMap());

  Future<List<ThesisAssessment>> thesisAssessments(int thesisId) async {
    final rows = await _db.query(
      'thesis_assessments',
      where: 'thesis_id = ?',
      whereArgs: [thesisId],
      orderBy: 'assessed_at DESC',
    );
    return rows.map(ThesisAssessment.fromMap).toList();
  }

  Future<List<PortfolioHolding>> portfolioHoldings() async {
    final rows = await _db.query('portfolio_holdings', where: 'local_deleted = 0', orderBy: 'id');
    return rows.map(PortfolioHolding.fromMap).toList();
  }

  Future<int> savePortfolioHolding(PortfolioHolding holding) async {
    if (holding.securityName.trim().isEmpty ||
        holding.ticker.trim().isEmpty ||
        holding.marketValueKzt < 0) {
      throw ArgumentError(
        'Enter a security name, ticker and non-negative KZT value.',
      );
    }
    return _db.transaction((txn) async {
      final values = {...holding.toMap(), 'is_synced': 0};
      final id = holding.id;
      final savedId = id ?? await txn.insert('portfolio_holdings', {...values, 'cloud_id': _newCloudId()});
      if (id != null) {
        final changed = await txn.update('portfolio_holdings', values,
          where: 'id = ? AND local_deleted = 0', whereArgs: [id]);
        if (changed != 1) throw StateError('The record is no longer available.');
      }
      await _recordSyncOp(
        executor: txn,
        entityType: 'portfolio_holding',
        entityId: savedId.toString(),
        operation: id == null ? 'create' : 'update',
        payload: holding.toMap(),
      );
      return savedId;
    });
  }

  Future<void> deletePortfolioHolding(int holdingId) =>
      _deleteInvestmentRecord('portfolio_holdings', 'portfolio_holding', holdingId);

  Future<void> _deleteInvestmentRecord(String table, String entity, int id) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(table, where: 'id = ? AND local_deleted = 0',
        whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final uid = _currentUid();
      if (uid != null) {
        await txn.delete('sync_operations',
          where: 'entity_type = ? AND entity_id = ? AND owner_uid = ? AND operation != ?',
          whereArgs: [entity, id.toString(), uid, 'delete']);
      }
      await _recordSyncOp(
        executor: txn, entityType: entity, entityId: id.toString(),
        operation: 'delete', payload: rows.single,
      );
      await txn.update(table, {'local_deleted': 1, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
    });
  }

  static const _syncTables = {
    'transaction': 'transactions',
    'goal': 'goals',
    'investment_thesis': 'investment_theses',
    'portfolio_holding': 'portfolio_holdings',
  };

  static String _newCloudId() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(18, (_) => random.nextInt(256)));
  }

  bool canSyncAccount(String uid) => (_accountUid ?? _currentUid()) == uid;

  /// Persist the remote identifier before issuing a write, so an ambiguous
  /// network response or process restart retries the same document.
  Future<String?> reserveCloudId(SyncOperation op) async {
    final table = _syncTables[op.entityType];
    final id = int.tryParse(op.entityId);
    if (table == null || id == null || op.ownerUid == null ||
        op.ownerUid != _currentUid()) {
      return null;
    }
    return _db.transaction((txn) async {
      final rows = await txn.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty || rows.single['local_deleted'] == 1) return null;
      final existing = rows.single['cloud_id'] as String?;
      if (existing != null && existing.isNotEmpty) return existing;
      final cloudId = _newCloudId();
      await txn.update(table, {'cloud_id': cloudId}, where: 'id = ?', whereArgs: [id]);
      return cloudId;
    });
  }

  Future<void> acknowledgeRecordUpload(SyncOperation op, String cloudId) async {
    final table = _syncTables[op.entityType]!;
    await _db.transaction((txn) async {
      final queued = await txn.query('sync_operations',
        where: 'entity_type = ? AND entity_id = ?', whereArgs: [op.entityType, op.entityId]);
      // A queued change (including a deletion) added while the upload was in
      // flight must remain visible as a conflict to subsequent downloads.
      if (queued.length != 1 || queued.single['id'] != op.id) return;
      await txn.update(table, {'cloud_id': cloudId, 'is_synced': 1,
        'synced_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [op.entityId]);
    });
  }

  /// A tombstone must never overwrite an unsynchronized local edit.
  Future<bool> applyInvestmentTombstone(String entityType, String cloudId) async {
    final table = _syncTables[entityType];
    if (table != 'investment_theses' && table != 'portfolio_holdings') {
      throw ArgumentError.value(entityType);
    }
    return _db.transaction((txn) async {
      final rows = await txn.query(table!, where: 'cloud_id = ?', whereArgs: [cloudId]);
      if (rows.isEmpty) return true;
      if (rows.length != 1) return false;
      if (rows.single['local_deleted'] == 1) return true;
      if (rows.single['is_synced'] != 1) return false;
      await txn.update(table, {'local_deleted': 1}, where: 'cloud_id = ?', whereArgs: [cloudId]);
      return true;
    });
  }

  Future<Map<String, String>> investmentSettings() async {
    final rows = await _db.query('investment_settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> saveInvestmentSetting(String key, String value) async {
    await _db.insert('investment_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _recordSyncOp(
      entityType: 'investment_setting',
      entityId: key,
      operation: 'create',
      payload: {'key': key, 'value': value},
    );
  }

  static const _portableTables = <String, String>{
    'transactions': 'id',
    'goals': 'id',
    'goal_contributions': 'id',
    'budgets': 'category',
    'investment_theses': 'id',
    'thesis_conditions': 'id',
    'thesis_assessments': 'id',
    'portfolio_holdings': 'id',
    'investment_settings': 'key',
    'investment_allocations': 'id',
    'cash_accounts': 'id',
    'watchlist': 'ticker',
    'advice': 'id',
    'ai_messages': 'id',
  };

  static const _seedSnapshotKey = 'initial_demo_snapshot';

  static Future<String> _seedSnapshot(DatabaseExecutor db) async {
    final present = await _tableNames(db);
    return jsonEncode({
      for (final entry in _portableTables.entries)
        if (present.contains(entry.key))
          entry.key: await db.query(entry.key, orderBy: entry.value),
    });
  }

  void _requireAccount(String uid) {
    if (_accountUid == null || _accountUid != uid) {
      throw StateError('The active account does not own this database.');
    }
  }

  static Future<Set<String>> _tableNames(DatabaseExecutor db) async =>
      (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
          .map((row) => row['name'] as String)
          .toSet();

  /// Keep the local write lock across remote cleanup so a new queued change
  /// cannot appear between the pending check and local deletion.
  Future<void> deleteAccountData(
    String uid,
    Future<void> Function() deleteCloud, {
    Future<void> Function(bool removeLegacy)? clearPreferences,
  }) async {
    _requireAccount(uid);
    final directory = paths.dirname(_db.path);
    final sharedPath = paths.join(directory, 'smartsave_demo.db');
    final sharedExists = await databaseExists(sharedPath);
    final legacyBelongsToAccount = await databaseExists(paths.join(directory, 'smartsave_legacy_claim.db')) &&
        await _legacyClaimBelongsTo(uid, directory);
    final removeLegacy = await _db.transaction((txn) async {
      const deletionMarker = 'account_deletion_prepared';
      final sealed = await txn.query('preferences', where: 'key = ?', whereArgs: [deletionMarker]);
      if (sealed.isNotEmpty) return sealed.single['value'] == 'legacy';
      final imported = await txn.query('preferences', where: 'key = ?',
        whereArgs: ['legacy_account_import_complete']);
      if (sharedExists && (!legacyBelongsToAccount || imported.isEmpty)) {
        throw StateError('Shared legacy records require confirmed recovery before deletion.');
      }
      final removeLegacy = legacyBelongsToAccount && imported.isNotEmpty;
      final pending = await txn.query('sync_operations',
        where: 'status != ?', whereArgs: ['synced'], limit: 1);
      if (pending.isNotEmpty) {
        throw StateError('Unsynchronized data must be resolved before deletion.');
      }
      final present = await _tableNames(txn);
      final tables = [
        ..._portableTables.keys,
        'preferences',
        'sync_operations',
        'deposit_products',
      ].reversed.where(present.contains);
      if (present.any((name) => !name.startsWith('sqlite_') && !tables.contains(name))) {
        throw StateError('Local data contains unsupported tables.');
      }
      // The cloud callback throws on any incomplete remote cleanup.
      await deleteCloud();
      for (final table in tables) {
        await txn.delete(table);
        if (table == 'preferences') {
          await txn.insert('preferences', {'key': deletionMarker, 'value': removeLegacy ? 'legacy' : '1'});
        }
        for (final operation in ['INSERT', 'UPDATE']) {
          await txn.execute(
            "CREATE TRIGGER IF NOT EXISTS deletion_${table}_$operation "
            "BEFORE $operation ON $table BEGIN SELECT RAISE(ABORT, 'Account deletion in progress'); END",
          );
        }
      }
      return removeLegacy;
    });
    await clearPreferences?.call(removeLegacy);
    if (removeLegacy && sharedExists) await deleteDatabase(sharedPath);
    final activePath = _db.path;
    final account = base64Url.encode(utf8.encode(uid));
    final original = paths.join(directory, 'smartsave_account_$account.db');
    await close();
    await deleteDatabase(activePath);
    if (activePath != original) {
      await deleteDatabase(original);
      await _secureStorage.delete(key: 'smartsave.sqlite.v1.$account');
    }
  }

  Future<bool> _legacyClaimBelongsTo(String uid, String directory) async {
    final claim = await openReadOnlyDatabase(
      paths.join(directory, 'smartsave_legacy_claim.db'), singleInstance: false,
    );
    try {
      final rows = await claim.query('legacy_claim');
      return rows.isNotEmpty && rows.single['uid'] == uid;
    } finally {
      await claim.close();
    }
  }

  /// Exports a consistent local snapshot without exporting credential/config tables.
  Future<String> exportAccountData(String uid) async {
    _requireAccount(uid);
    return _db.transaction((txn) async {
      final present = await _tableNames(txn);
      return const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'source': 'local_account_cache',
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'records': {
          for (final entry in _portableTables.entries)
            if (entry.key != 'ai_messages' && present.contains(entry.key))
              entry.key: await txn.query(entry.key, orderBy: entry.value,
                where: entry.key == 'investment_theses' || entry.key == 'portfolio_holdings'
                    ? 'local_deleted = 0' : null),
        },
      });
    });
  }

  /// Imports a confirmed single-owner legacy snapshot. Conflicts abort the entire
  /// import. The read-only source and unscoped preferences remain recoverable.
  Future<void> importLegacyAccountData(
    String uid, {
    required bool ownershipConfirmed,
    String? assistantHistory,
  }) async {
    _requireAccount(uid);
    if (!ownershipConfirmed) throw StateError('Confirm ownership first.');
    final sourcePath = paths.join(paths.dirname(_db.path), 'smartsave_demo.db');
    final source = await databaseExists(sourcePath)
        ? await openReadOnlyDatabase(sourcePath, singleInstance: false) : null;
    if (source == null && assistantHistory == null) {
      throw StateError('No legacy records are available on this device.');
    }
    try {
      final tables = {..._portableTables, 'sync_operations': 'id'};
      final snapshot = <String, List<Map<String, Object?>>>{};
      if (source != null) {
        final integrity = await source.rawQuery('PRAGMA quick_check');
        if (integrity.length != 1 || integrity.single.values.single != 'ok') {
          throw StateError('The original database failed its integrity check.');
        }
        final present = await _tableNames(source);
        for (final name in tables.keys.where(present.contains)) {
          snapshot[name] = await source.query(name);
        }
      }
      final queue = snapshot['sync_operations'] ?? const [];
      if (queue.any((row) => row['owner_uid'] != null && row['owner_uid'] != uid)) {
        throw StateError('The legacy database has records associated with another account.');
      }
      if (assistantHistory != null && jsonDecode(assistantHistory) is! List) {
        throw const FormatException('Invalid legacy assistant history.');
      }
      // Reserve ownership before writing the destination. If the process stops
      // between these transactions, only the same account can resume.
      final claim = await openDatabase(
        paths.join(paths.dirname(sourcePath), 'smartsave_legacy_claim.db'),
        version: 1,
        singleInstance: false,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE legacy_claim (id INTEGER PRIMARY KEY CHECK (id = 1), uid TEXT NOT NULL)',
        ),
      );
      try {
        await claim.transaction((txn) async {
          final rows = await txn.query('legacy_claim');
          if (rows.isEmpty) {
            await txn.insert('legacy_claim', {'id': 1, 'uid': uid});
          } else if (rows.single['uid'] != uid) {
            throw StateError('The legacy database has already been claimed.');
          }
        });
      } finally {
        await claim.close();
      }
      await _db.transaction((txn) async {
        const marker = 'legacy_account_import_complete';
        final complete = await txn.query('preferences',
          where: 'key = ?', whereArgs: [marker]);
        if (complete.isNotEmpty) return;

        final initial = await txn.query('preferences',
          where: 'key = ?', whereArgs: [_seedSnapshotKey]);
        if (initial.isNotEmpty &&
            (await txn.query('sync_operations', limit: 1)).isEmpty &&
            initial.single['value'] == await _seedSnapshot(txn)) {
          for (final table in _portableTables.keys.toList().reversed) {
            if (snapshot.containsKey(table)) await txn.delete(table);
          }
        }

        for (final entry in snapshot.entries) {
          final key = tables[entry.key]!;
          for (final original in entry.value) {
            final row = <String, Object?>{...original};
            final id = row[key];
            if (id == null) throw StateError('Legacy record has no stable ID.');
            final cloudId = row['cloud_id'];
            if (cloudId is String && cloudId.isNotEmpty &&
                (await txn.query(entry.key, where: 'cloud_id = ? AND $key != ?',
                    whereArgs: [cloudId, id], limit: 1)).isNotEmpty) {
              throw StateError('A legacy record duplicates an existing cloud record.');
            }
            final existing = await txn.query(entry.key, where: '$key = ?', whereArgs: [id]);
            if (existing.isEmpty) await txn.insert(entry.key, row);
            final stored = (await txn.query(entry.key, where: '$key = ?', whereArgs: [id])).single;
            if (row.entries.any((field) => stored[field.key] != field.value)) {
              throw StateError('A legacy record conflicts with an existing account record.');
            }
          }
        }
        if (assistantHistory != null) {
          const key = 'assistant_conversation_history';
          final conflicts = await txn.query('preferences', where: 'key = ?', whereArgs: [key]);
          if (conflicts.isEmpty) {
            await txn.insert('preferences', {'key': key, 'value': assistantHistory});
          } else if (conflicts.single['value'] != assistantHistory) {
            throw StateError('Legacy assistant history conflicts with account history.');
          }
        }
        if ((await txn.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
          throw StateError('Legacy records failed integrity checks.');
        }
        await txn.delete('preferences', where: 'key = ?', whereArgs: [_seedSnapshotKey]);
        await txn.insert('preferences', {'key': marker, 'value': '1'});
      });
    } finally {
      await source?.close();
    }
  }

  Future<String?> assistantConversationHistory() async {
    final rows = await _db.query(
      'preferences',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['assistant_conversation_history'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  Future<void> saveAssistantConversationHistory(String history) async {
    await _db.insert(
      'preferences',
      {'key': 'assistant_conversation_history', 'value': history},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AIMessage>> aiMessages() async {
    final rows = await _db.query('ai_messages', orderBy: 'timestamp ASC');
    return rows.map(AIMessage.fromMap).toList();
  }

  Future<void> saveAIMessage(AIMessage message) async {
    await _db.insert('ai_messages', message.toMap());
  }

  Future<void> clearAIMessages() async {
    await _db.delete('ai_messages');
  }

  Future<void> resetDemoData() async {
    if (_currentUid() != null) {
      throw StateError('An authenticated account cannot be reset as demo data.');
    }
    await _db.transaction((txn) async {
      for (final table in [
        'transactions',
        'goal_contributions',
        'goals',
        'budgets',
        'preferences',
        'advice',
        'watchlist',
        'deposit_products',
      ]) {
        await txn.delete(table);
      }
      await _seed(txn);
    });
  }

  // ===== Sync-related methods =====

  /// Add sync metadata columns to tables and create the sync operations queue.
  /// Idempotent: safe to call on a new or existing database without losing data.
  static Future<void> _ensureSyncColumns(DatabaseExecutor db) async {
    final tables = [
      'transactions',
      'goals',
      'goal_contributions',
      'budgets',
      'investment_theses',
      'thesis_conditions',
      'thesis_assessments',
      'portfolio_holdings',
      'investment_settings',
    ];

    for (final table in tables) {
      final columns = await db.rawQuery("PRAGMA table_info($table)");
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      if ((table == 'investment_theses' || table == 'portfolio_holdings') &&
          !columnNames.contains('local_deleted')) {
        await db.execute('ALTER TABLE $table ADD COLUMN local_deleted INTEGER NOT NULL DEFAULT 0');
      }
      if (!columnNames.contains('cloud_id')) {
        await db.execute('ALTER TABLE $table ADD COLUMN cloud_id TEXT');
      }
      if (!columnNames.contains('synced_at')) {
        await db.execute('ALTER TABLE $table ADD COLUMN synced_at TEXT');
      }
      if (!columnNames.contains('sync_version')) {
        await db.execute(
          'ALTER TABLE $table ADD COLUMN sync_version INTEGER DEFAULT 1',
        );
      }
      if (!columnNames.contains('is_synced')) {
        await db.execute(
          'ALTER TABLE $table ADD COLUMN is_synced INTEGER DEFAULT 0',
        );
      }
      if (!columnNames.contains('local_version')) {
        await db.execute(
          'ALTER TABLE $table ADD COLUMN local_version INTEGER DEFAULT 1',
        );
      }
    }

    // Create sync_operations table if not exists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_operations (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        retry_count INTEGER DEFAULT 0,
        owner_uid TEXT
      )
    ''');
    final queueColumns = await db.rawQuery(
      'PRAGMA table_info(sync_operations)',
    );
    if (!queueColumns.any((column) => column['name'] == 'owner_uid')) {
      await db.execute('ALTER TABLE sync_operations ADD COLUMN owner_uid TEXT');
    }
  }

  /// Initialize sync columns on repository open
  /// Safe to call multiple times — idempotent.
  Future<void> initializeSync() async {
    await _ensureSyncColumns(_db);
  }

  /// Record a local change to the pending sync queue.
  /// Used by mutating repository methods to queue uploads to Firestore.
  Future<void> _recordSyncOp({
    DatabaseExecutor? executor,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = executor ?? _db;
    final ownerUid = _currentUid();
    final opId =
        '${entityType}_${entityId}_${DateTime.now().microsecondsSinceEpoch}';
    await db.insert('sync_operations', {
      'id': opId,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'owner_uid': ownerUid?.trim().isNotEmpty == true ? ownerUid : null,
    });
  }

  /// Mark a sync operation as successfully completed by deleting it from the queue.
  Future<void> _deleteSyncOperation(String operationId) async {
    await _db.delete(
      'sync_operations',
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  /// Mark a sync operation as failed, incrementing its retry counter.
  /// Called by SyncService when an upload/download attempt fails.
  Future<void> _failSyncOperation(String operationId, String error) async {
    await _db.rawUpdate(
      'UPDATE sync_operations SET status = ?, error_message = ?, retry_count = retry_count + 1 WHERE id = ?',
      ['error', error, operationId],
    );
  }

  // ===== Transaction sync methods =====

  Future<FinanceTransaction?> getTransactionById(int id) async {
    final rows = await _db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FinanceTransaction.fromMap(rows.first);
  }

  Future<void> markTransactionSynced(int localId, String cloudId) async {
    await _db.update(
      'transactions',
      {
        'cloud_id': cloudId,
        'synced_at': DateTime.now().toIso8601String(),
        'is_synced': 1,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ===== Goal sync methods =====

  Future<SavingsGoal?> getGoalById(int id) async {
    final rows = await _db.query(
      'goals',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SavingsGoal.fromMap(rows.first);
  }

  Future<void> markGoalSynced(int localId, String cloudId) async {
    await _db.update(
      'goals',
      {
        'cloud_id': cloudId,
        'synced_at': DateTime.now().toIso8601String(),
        'is_synced': 1,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ===== Portfolio Holding sync methods =====

  Future<PortfolioHolding?> getPortfolioHoldingById(int id) async {
    final rows = await _db.query(
      'portfolio_holdings',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PortfolioHolding.fromMap(rows.first);
  }

  Future<void> markHoldingSynced(int localId, String cloudId) async {
    await _db.update(
      'portfolio_holdings',
      {
        'cloud_id': cloudId,
        'synced_at': DateTime.now().toIso8601String(),
        'is_synced': 1,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ===== Investment Thesis sync methods =====

  Future<InvestmentThesis?> getInvestmentThesisById(int id) async {
    final rows = await _db.query(
      'investment_theses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return InvestmentThesis.fromMap(rows.first);
  }

  // ===== Cloud-to-local application (download) =====
  // These methods apply remote Firestore data to local SQLite WITHOUT
  // recording sync operations, preventing infinite sync loops.

  Future<bool> applyCloudTransaction(FinanceTransaction record, String cloudId) =>
      _applyCloudRecord('transactions', record.toMap(), cloudId);

  Future<bool> applyCloudGoal(SavingsGoal record, String cloudId) =>
      _applyCloudRecord('goals', record.toMap(), cloudId);

  Future<bool> applyCloudHolding(PortfolioHolding record, String cloudId) =>
      _applyCloudRecord('portfolio_holdings', record.toMap(), cloudId);

  Future<bool> applyCloudThesis(InvestmentThesis record, String cloudId) =>
      _applyCloudRecord('investment_theses', record.toMap(), cloudId);

  Future<bool> _applyCloudRecord(
    String table, Map<String, Object?> record, String cloudId,
  ) => _db.transaction((txn) async {
    final rows = await txn.query(table, where: 'cloud_id = ?', whereArgs: [cloudId]);
    if (rows.length > 1) return false;
    final existing = rows.firstOrNull;
    if (existing != null && (existing['is_synced'] != 1 || existing['local_deleted'] == 1)) {
      return false;
    }
    final values = {
      ...record,
      'cloud_id': cloudId,
      'is_synced': 1,
      'synced_at': DateTime.now().toIso8601String(),
    };
    if (existing == null) {
      await txn.insert(table, values);
    } else {
      await txn.update(table, values, where: 'id = ?', whereArgs: [existing['id']]);
    }
    return true;
  });

  /// Apply a cloud budget to local SQLite (remote-wins for budgets).
  Future<bool> applyCloudBudget(String category, int monthlyLimit) async {
    final existing = await _db.query(
      'budgets',
      where: 'category = ?',
      whereArgs: [category],
      limit: 1,
    );
    if (existing.isNotEmpty && (existing.first['is_synced'] as int? ?? 0) == 0) {
      return false;
    }
    await _db.insert('budgets', {
      'category': category,
      'monthly_limit': monthlyLimit,
      'cloud_id': category,
      'is_synced': 1,
      'synced_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  /// Apply a cloud investment setting unless it has a pending local edit.
  Future<bool> applyCloudSetting(String key, String value) async {
    final existing = await _db.query(
      'investment_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (existing.isNotEmpty && (existing.first['is_synced'] as int? ?? 0) == 0) {
      return false;
    }
    await _db.insert('investment_settings', {
      'key': key,
      'value': value,
      'cloud_id': key,
      'is_synced': 1,
      'synced_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  /// Get all pending sync operations with retry count info.
  Future<List<Map<String, dynamic>>> getPendingOpsWithRetry() async {
    final rows = await _db.query(
      'sync_operations',
      where: 'status IN (?, ?)',
      whereArgs: ['pending', 'error'],
      orderBy: 'created_at',
    );
    return rows;
  }

  /// Get a single local entity by cloud_id for upload verification.
  Future<Map<String, Object?>?> getLocalRowByCloudId(
    String table,
    String cloudId,
  ) async {
    final rows = await _db.query(
      table,
      where: 'cloud_id = ?',
      whereArgs: [cloudId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Delete a completed sync operation from the queue.
  Future<void> removeSyncOperation(String operationId) async {
    await _deleteSyncOperation(operationId);
  }

  /// Mark a sync operation as failed (increments retry count).
  Future<void> failSyncOperation(String operationId, String error) async {
    await _failSyncOperation(operationId, error);
  }

  Future<void> markInvestmentThesisSynced(int localId, String cloudId) async {
    await _db.update(
      'investment_theses',
      {
        'cloud_id': cloudId,
        'synced_at': DateTime.now().toIso8601String(),
        'is_synced': 1,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ===== Sync Operations =====

  /// Record a sync operation for offline queue
  Future<void> recordSyncOperation({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    String? ownerUid,
  }) async {
    final accountUid = _currentUid();
    if (accountUid != null && ownerUid != accountUid) {
      throw StateError('A queued operation must belong to the database account.');
    }
    await _db.insert('sync_operations', {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'owner_uid': ownerUid,
    });
  }

  /// Get pending sync operations
  Future<List<SyncOperation>> getPendingSyncOperations() async {
    final rows = await _db.query(
      'sync_operations',
      where: 'status IN (?, ?)',
      whereArgs: ['pending', 'error'],
      orderBy: 'created_at',
    );

    return rows
        .map(
          (row) => SyncOperation(
            id: row['id'] as String,
            entityType: row['entity_type'] as String,
            entityId: row['entity_id'] as String,
            operation: row['operation'] as String,
            payload: jsonDecode(row['payload'] as String),
            createdAt: DateTime.parse(row['created_at'] as String),
            status: row['status'] as String,
            ownerUid: row['owner_uid'] as String?,
          ),
        )
        .toList();
  }

  /// Get pending sync count
  Future<int> getPendingSyncCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_operations WHERE status IN (?, ?)',
      ['pending', 'error'],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Mark sync operation as failed
  Future<void> markSyncOperationFailed(String operationId, String error) async {
    await _db.rawUpdate(
      'UPDATE sync_operations SET status = ?, error_message = ?, retry_count = retry_count + 1 WHERE id = ?',
      ['error', error, operationId],
    );
  }

  /// Clear sync conflict
  Future<void> clearSyncConflict(String operationId) async {
    await _db.update(
      'sync_operations',
      {'status': 'pending'},
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  Future<void> close() => _db.close();
}

int _roundedPercentChange(int current, int previous) {
  final difference = current - previous;
  final magnitude = (difference.abs() * 100 + previous ~/ 2) ~/ previous;
  return difference < 0 ? -magnitude : magnitude;
}

/// Sync operation model for offline queue
class SyncOperation {
  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String status;
  final String? ownerUid;

  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.status = 'pending',
    this.ownerUid,
  });
}
