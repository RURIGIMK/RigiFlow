import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../ingestion/models/transaction_model.dart';

class TransactionDatabase {
  static final TransactionDatabase _instance = TransactionDatabase._internal();
  factory TransactionDatabase() => _instance;
  TransactionDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'rigiflow.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA synchronous=NORMAL');
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

  /// HIGH PERFORMANCE: Inserts multiple transactions in a single batch
  /// This is much more battery-efficient for initial imports.
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

  Future<List<TransactionModel>> getTransactions({int limit = 50, int offset = 0}) async {
    final db = await database;
    final maps = await db.query(
      'transactions', 
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
