import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../ingestion/models/transaction_model.dart';
import '../../forecasting/models/forecast_result.dart';

class TransactionDatabase {
  static final TransactionDatabase _instance = TransactionDatabase._internal();
  factory TransactionDatabase() => _instance;
  TransactionDatabase._internal();

  Database? _db;
  Completer<Database>? _initCompleter;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;

    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<Database>();
    try {
      _db = await _initDb();
      _initCompleter!.complete(_db);
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'rigiflow.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        try {
          await db.rawQuery('PRAGMA journal_mode=WAL');
        } catch (_) {}
        try {
          await db.execute('PRAGMA synchronous=NORMAL');
        } catch (_) {}
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            raw_sms TEXT NOT NULL,
            amount REAL NOT NULL,
            direction TEXT NOT NULL,
            source TEXT NOT NULL,
            counterparty TEXT,
            transaction_code TEXT UNIQUE,
            category TEXT NOT NULL DEFAULT 'Uncategorized',
            timestamp INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_transactions_timestamp ON transactions (timestamp DESC)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('CREATE INDEX idx_transactions_timestamp ON transactions (timestamp DESC)');
        }
      },
    );
  }

  Future<TransactionModel> insertTransaction(TransactionModel tx) async {
    final db = await database;
    final id = await db.insert(
      'transactions',
      tx.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return tx.copyWith(id: id > 0 ? id : null);
  }

  Future<void> insertTransactionsBatch(List<TransactionModel> transactions) async {
    if (transactions.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final tx in transactions) {
        batch.insert(
          'transactions',
          tx.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<TransactionModel>> getTransactionsBefore({
    DateTime? beforeTimestamp,
    int? beforeId,
    int limit = 30,
  }) async {
    final db = await database;
    List<Map<String, dynamic>> maps;

    if (beforeTimestamp == null || beforeId == null) {
      maps = await db.query('transactions', orderBy: 'timestamp DESC, id DESC', limit: limit);
    } else {
      maps = await db.query(
        'transactions',
        where: '(timestamp < ?) OR (timestamp = ? AND id < ?)',
        whereArgs: [
          beforeTimestamp.millisecondsSinceEpoch,
          beforeTimestamp.millisecondsSinceEpoch,
          beforeId,
        ],
        orderBy: 'timestamp DESC, id DESC',
        limit: limit,
      );
    }
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<List<TransactionModel>> getFilteredTransactions({
    TransactionDirection? direction,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    DateTime? beforeTimestamp,
    int? beforeId,
    int limit = 30,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];

    if (direction != null) {
      conditions.add('direction = ?');
      args.add(direction.name);
    }
    if (startDate != null) {
      conditions.add('timestamp >= ?');
      args.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      conditions.add('timestamp <= ?');
      args.add(endDate.millisecondsSinceEpoch);
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (beforeTimestamp != null && beforeId != null) {
      conditions.add('(timestamp < ? OR (timestamp = ? AND id < ?))');
      args.addAll([
        beforeTimestamp.millisecondsSinceEpoch,
        beforeTimestamp.millisecondsSinceEpoch,
        beforeId,
      ]);
    }

    final whereClause = conditions.isEmpty ? null : conditions.join(' AND ');

    final maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC, id DESC',
      limit: limit,
    );
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<void> updateCategory(int transactionId, String category) async {
    final db = await database;
    await db.update(
      'transactions',
      {'category': category},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  // ---------------- Module 4: forecasting queries ----------------

  /// Daily spend totals (money out, excluding Savings — that's saving,
  /// not spending) within a date range, keyed 'YYYY-MM-DD'. 'localtime'
  /// keeps day boundaries aligned to the phone's actual calendar day
  /// rather than UTC, which matters for Kenya's UTC+3 offset.
  Future<Map<String, double>> getDailySpendTotals({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT strftime('%Y-%m-%d', timestamp/1000, 'unixepoch', 'localtime') as day,
             SUM(amount) as total
      FROM transactions
      WHERE direction = ? AND category != ? AND timestamp >= ? AND timestamp <= ?
      GROUP BY day
      ORDER BY day ASC
    ''', [
      TransactionDirection.moneyOut.name,
      'Savings',
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    ]);

    return {
      for (final row in rows)
        row['day'] as String: (row['total'] as num).toDouble(),
    };
  }

  /// Total per category within a date range, for a given direction —
  /// defaults to money out, which is what a spend breakdown wants.
  Future<Map<String, double>> getCategoryTotals({
    required DateTime start,
    required DateTime end,
    TransactionDirection direction = TransactionDirection.moneyOut,
  }) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE direction = ? AND timestamp >= ? AND timestamp <= ?
      GROUP BY category
      ORDER BY total DESC
    ''', [direction.name, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);

    return {
      for (final row in rows)
        row['category'] as String: (row['total'] as num).toDouble(),
    };
  }

  /// Average monthly spend per category over a historical window
  /// (e.g. the 3 complete months before this one) — the baseline that
  /// this month's spend gets compared against for anomaly detection.
  Future<Map<String, double>> getHistoricalCategoryAverages({
    required DateTime historyStart,
    required DateTime historyEnd,
    required int monthsSpanned,
  }) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE direction = ? AND timestamp >= ? AND timestamp < ?
      GROUP BY category
    ''', [
      TransactionDirection.moneyOut.name,
      historyStart.millisecondsSinceEpoch,
      historyEnd.millisecondsSinceEpoch,
    ]);

    final divisor = monthsSpanned > 0 ? monthsSpanned : 1;
    return {
      for (final row in rows)
        row['category'] as String: (row['total'] as num).toDouble() / divisor,
    };
  }

  /// One row per calendar month with any activity — income and spend
  /// (spend excludes Savings deposits, matching the rest of the
  /// forecasting layer) — the data behind the Monthly Reports screen
  /// and the backtesting engine's historical months.
  Future<List<MonthlySummary>> getMonthlySummaries() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        strftime('%Y-%m', timestamp/1000, 'unixepoch', 'localtime') as month,
        SUM(CASE WHEN direction = 'moneyIn' THEN amount ELSE 0 END) as total_in,
        SUM(CASE WHEN direction = 'moneyOut' AND category != 'Savings' THEN amount ELSE 0 END) as total_out
      FROM transactions
      GROUP BY month
      ORDER BY month ASC
    ''');

    return rows.map((row) {
      final monthKey = row['month'] as String;
      final parts = monthKey.split('-');
      return MonthlySummary(
        monthKey: monthKey,
        monthStart: DateTime(int.parse(parts[0]), int.parse(parts[1]), 1),
        totalIn: (row['total_in'] as num).toDouble(),
        totalOut: (row['total_out'] as num).toDouble(),
      );
    }).toList();
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      _initCompleter = null;
    }
  }
}