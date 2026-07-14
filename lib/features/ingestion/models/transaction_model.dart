enum TransactionDirection { moneyIn, moneyOut }

enum TransactionSource { mpesa, equity, kcb, unknown }

class TransactionModel {
  final int? id;
  final String rawSms;
  final double amount;
  final TransactionDirection direction;
  final TransactionSource source;
  final String? counterparty;
  final String? transactionCode;
  final String category;
  final DateTime timestamp;
  final DateTime createdAt;

  TransactionModel({
    this.id,
    required this.rawSms,
    required this.amount,
    required this.direction,
    required this.source,
    this.counterparty,
    this.transactionCode,
    this.category = 'Uncategorized',
    required this.timestamp,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  TransactionModel copyWith({
    int? id,
    String? rawSms,
    double? amount,
    TransactionDirection? direction,
    TransactionSource? source,
    String? counterparty,
    String? transactionCode,
    String? category,
    DateTime? timestamp,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      rawSms: rawSms ?? this.rawSms,
      amount: amount ?? this.amount,
      direction: direction ?? this.direction,
      source: source ?? this.source,
      counterparty: counterparty ?? this.counterparty,
      transactionCode: transactionCode ?? this.transactionCode,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'raw_sms': rawSms,
      'amount': amount,
      'direction': direction.name,
      'source': source.name,
      'counterparty': counterparty,
      'transaction_code': transactionCode,
      'category': category,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    try {
      return TransactionModel(
        id: map['id'] as int?,
        rawSms: map['raw_sms'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        direction: TransactionDirection.values.firstWhere(
          (e) => e.name == map['direction'],
          orElse: () => TransactionDirection.moneyOut,
        ),
        source: TransactionSource.values.firstWhere(
          (e) => e.name == map['source'],
          orElse: () => TransactionSource.unknown,
        ),
        counterparty: map['counterparty'] as String?,
        transactionCode: map['transaction_code'] as String?,
        category: map['category'] as String? ?? 'Uncategorized',
        timestamp: DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as num?)?.toInt() ?? 0),
        createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at'] as num?)?.toInt() ?? 0),
      );
    } catch (e) {
      return TransactionModel(
        rawSms: 'Data error',
        amount: 0.0,
        direction: TransactionDirection.moneyOut,
        source: TransactionSource.unknown,
        timestamp: DateTime.now(),
      );
    }
  }
}