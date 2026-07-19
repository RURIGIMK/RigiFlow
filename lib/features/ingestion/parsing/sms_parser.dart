import '../models/transaction_model.dart';
import 'parser_patterns.dart';

class SmsParser {
  static TransactionModel? parse({
    required String sender,
    required String body,
    required DateTime receivedAt,
  }) {
    try {
      // Normalize sender: remove hyphens and spaces for better matching
      final normalizedSender = sender.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

      if (normalizedSender.contains('MPESA')) {
        return _parseMpesa(body, receivedAt);
      }
      if (normalizedSender.contains('EQUITY') ||
          normalizedSender.contains('KCB') ||
          normalizedSender.contains('COOP') ||
          normalizedSender.contains('ABSA') ||
          normalizedSender.contains('NCBA')) {
        return _parseBank(sender, body, receivedAt);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  static double _parseAmount(String raw) {
    try {
      final clean = raw.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(clean) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  static TransactionModel? _parseMpesa(String body, DateTime receivedAt) {
    var match = ParserPatterns.mpesaReceived.firstMatch(body);
    if (match != null) {
      return TransactionModel(
        rawSms: body,
        amount: _parseAmount(match.group(2)!),
        direction: TransactionDirection.moneyIn,
        source: TransactionSource.mpesa,
        counterparty: match.group(3)?.trim(),
        transactionCode: match.group(1),
        timestamp: receivedAt,
      );
    }

    match = ParserPatterns.mpesaTransferFromSavings.firstMatch(body);
    if (match != null) {
      return TransactionModel(
        rawSms: body,
        amount: _parseAmount(match.group(2)!),
        direction: TransactionDirection.moneyIn,
        source: TransactionSource.mpesa,
        counterparty: match.group(3)?.trim(),
        transactionCode: match.group(1),
        category: 'Savings',
        timestamp: receivedAt,
      );
    }

    match = ParserPatterns.mpesaTransferToSavings.firstMatch(body);
    if (match != null) {
      return TransactionModel(
        rawSms: body,
        amount: _parseAmount(match.group(2)!),
        direction: TransactionDirection.moneyOut,
        source: TransactionSource.mpesa,
        counterparty: match.group(3)?.trim(),
        transactionCode: match.group(1),
        category: 'Savings',
        timestamp: receivedAt,
      );
    }

    match = ParserPatterns.mpesaSent.firstMatch(body);
    if (match != null) {
      return TransactionModel(
        rawSms: body,
        amount: _parseAmount(match.group(2)!),
        direction: TransactionDirection.moneyOut,
        source: TransactionSource.mpesa,
        counterparty: match.group(3)?.trim(),
        transactionCode: match.group(1),
        timestamp: receivedAt,
      );
    }

    match = ParserPatterns.mpesaPaybill.firstMatch(body);
    if (match != null) {
      return TransactionModel(
        rawSms: body,
        amount: _parseAmount(match.group(2)!),
        direction: TransactionDirection.moneyOut,
        source: TransactionSource.mpesa,
        counterparty: match.group(3)?.trim(),
        transactionCode: match.group(1),
        timestamp: receivedAt,
      );
    }

    match = ParserPatterns.mpesaWithdraw.firstMatch(body);
    if (match != null) {
      return TransactionModel(
        rawSms: body,
        amount: _parseAmount(match.group(2)!),
        direction: TransactionDirection.moneyOut,
        source: TransactionSource.mpesa,
        counterparty: match.group(3)?.trim(),
        transactionCode: match.group(1),
        timestamp: receivedAt,
      );
    }

    match = ParserPatterns.mpesaAirtime.firstMatch(body);
    if (match != null) {
      return TransactionModel(
        rawSms: body,
        amount: _parseAmount(match.group(2)!),
        direction: TransactionDirection.moneyOut,
        source: TransactionSource.mpesa,
        counterparty: 'Airtime',
        transactionCode: match.group(1),
        timestamp: receivedAt,
      );
    }

    match = ParserPatterns.mpesaTill.firstMatch(body);
    if (match != null) {
      return TransactionModel(
        rawSms: body,
        amount: _parseAmount(match.group(2)!),
        direction: TransactionDirection.moneyOut,
        source: TransactionSource.mpesa,
        counterparty: match.group(3)?.trim(),
        transactionCode: match.group(1),
        timestamp: receivedAt,
      );
    }

    return null;
  }

  static TransactionModel? _parseBank(
      String sender, String body, DateTime receivedAt) {
    final source = _bankSourceFromSender(sender);

    var match = ParserPatterns.bankCredit.firstMatch(body);
    if (match != null) {
      return TransactionModel(
        rawSms: body,
        amount: _parseAmount(match.group(1)!),
        direction: TransactionDirection.moneyIn,
        source: source,
        timestamp: receivedAt,
      );
    }

    match = ParserPatterns.bankDebit.firstMatch(body);
    if (match != null) {
      return TransactionModel(
        rawSms: body,
        amount: _parseAmount(match.group(1)!),
        direction: TransactionDirection.moneyOut,
        source: source,
        timestamp: receivedAt,
      );
    }

    return null;
  }

  static TransactionSource _bankSourceFromSender(String sender) {
    final s = sender.toUpperCase();
    if (s.contains('EQUITY')) return TransactionSource.equity;
    if (s.contains('KCB')) return TransactionSource.kcb;
    return TransactionSource.unknown;
  }
}