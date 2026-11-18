import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';

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
  FinanceRepository._(this._db);
  final Database _db;

  static Future<FinanceRepository> open({String? databasePath}) async {
    final path =
        databasePath ??
        paths.join(await getDatabasesPath(), 'smartsave_demo.db');
    final db = await openDatabase(
      path,
      version: 3,
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
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createInvestmentTables(db);
        if (oldVersion < 3) await _createAIMessagesTable(db);
      },
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
    return FinanceRepository._(db);
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

  static Future<void> _createInvestmentAllocationsTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE investment_allocations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      security_type TEXT NOT NULL,
      security_name TEXT NOT NULL,
      ticker TEXT,
      exchange TEXT DEFAULT 'KASE',
      amount_kzt INTEGER NOT NULL CHECK(amount_kzt > 0),
      current_value_kzt INTEGER NOT NULL CHECK(current_value_kzt >= 0),
      linked_goal_id INTEGER REFERENCES goals(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT ''
    )''');
  }

  static Future<void> _createCashAccountsTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE cash_accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      balance_kzt INTEGER NOT NULL DEFAULT 0,
      is_investable INTEGER NOT NULL DEFAULT 1,
      opened_at TEXT NOT NULL
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
    final values = transaction.toMap();
    if (transaction.id == null) return _db.insert('transactions', values);
    await _db.update(
      'transactions',
      values,
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
    return transaction.id!;
  }

  Future<void> deleteTransaction(int id) =>
      _db.delete('transactions', where: 'id = ?', whereArgs: [id]);

  Future<List<SavingsGoal>> goals() async {
    final rows = await _db.query('goals', orderBy: 'deadline ASC');
    return rows.map(SavingsGoal.fromMap).toList();
  }

  Future<int> saveGoal(SavingsGoal goal) async {
    if (goal.name.trim().isEmpty || goal.target <= 0) {
      throw ArgumentError('Enter a goal name and a positive target.');
    }
    if (goal.id == null) return _db.insert('goals', goal.toMap());
    await _db.update(
      'goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
    return goal.id!;
  }

  Future<void> deleteGoal(int id) async {
    await _db.transaction((txn) async {
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
      orderBy: 'updated_at DESC',
    );
    return rows.map(InvestmentThesis.fromMap).toList();
  }

  Future<int> saveInvestmentThesis(InvestmentThesis thesis) async {
    if (thesis.securityName.trim().isEmpty || thesis.ticker.trim().isEmpty) {
      throw ArgumentError('Enter a security name and ticker.');
    }
    if (thesis.id == null) {
      return _db.insert('investment_theses', thesis.toMap());
    }
    await _db.update(
      'investment_theses',
      thesis.toMap(),
      where: 'id = ?',
      whereArgs: [thesis.id],
    );
    return thesis.id!;
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
      _db.delete('investment_theses', where: 'id = ?', whereArgs: [thesisId]);

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
    final rows = await _db.query('portfolio_holdings', orderBy: 'id');
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
    if (holding.id == null) {
      return _db.insert('portfolio_holdings', holding.toMap());
    }
    await _db.update(
      'portfolio_holdings',
      holding.toMap(),
      where: 'id = ?',
      whereArgs: [holding.id],
    );
    return holding.id!;
  }

  Future<void> deletePortfolioHolding(int holdingId) =>
      _db.delete('portfolio_holdings', where: 'id = ?', whereArgs: [holdingId]);

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

  Future<void> close() => _db.close();
}

int _roundedPercentChange(int current, int previous) {
  final difference = current - previous;
  final magnitude = (difference.abs() * 100 + previous ~/ 2) ~/ previous;
  return difference < 0 ? -magnitude : magnitude;
}
