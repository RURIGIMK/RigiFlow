import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../ingestion/models/transaction_model.dart';

class TransactionDatabase {
  static final TransactionDatabase _instance = TransactionDatabase._internal();
  factory TransactionDatabase() => _instance;
  TransactionDatabase._internal();

  Database? _db;
  Completer<Database>? _initCompleter;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;

    // If another call is already opening the DB, wait for that instead
    // of racing to open it twice.
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
        } catch (_) {
          // Non-critical optimization; safe to continue without it.
        }
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

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      _initCompleter = null;
    }
  }
}