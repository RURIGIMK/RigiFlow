import 'dart:async';
import 'package:telephony/telephony.dart';
import 'parsing/sms_parser.dart';
import 'parsing/parser_patterns.dart';
import '../transactions/database/transaction_db.dart';
import '../ingestion/models/transaction_model.dart';

@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  // Use a local instance to ensure isolation and proper closing
  final db = TransactionDatabase();
  
  final parsed = SmsParser.parse(
    sender: message.address ?? '',
    body: message.body ?? '',
    receivedAt: DateTime.fromMillisecondsSinceEpoch(
      message.date ?? DateTime.now().millisecondsSinceEpoch,
    ),
  );
  
  if (parsed != null) {
    await db.insertTransaction(parsed);
  }
  
  // Crucial for battery: release database and hardware locks immediately
  await db.close();
}

class SmsListenerService {
  static final SmsListenerService _instance = SmsListenerService._internal();
  factory SmsListenerService() => _instance;
  SmsListenerService._internal();

  final Telephony _telephony = Telephony.instance;
  final _transactionStreamController = StreamController<TransactionModel>.broadcast();
  bool _isListening = false;
  
  bool? _cachedPermissionStatus;

  Stream<TransactionModel> get newTransactions => _transactionStreamController.stream;

  Future<bool> requestPermissions() async {
    final granted = await _telephony.requestSmsPermissions;
    _cachedPermissionStatus = granted ?? false;
    return _cachedPermissionStatus!;
  }

  Future<bool> hasPermissions() async {
    if (_cachedPermissionStatus != null) return _cachedPermissionStatus!;
    final granted = await _telephony.requestSmsPermissions;
    _cachedPermissionStatus = granted ?? false;
    return _cachedPermissionStatus!;
  }

  void startListening() {
    if (_isListening) return;
    _isListening = true;

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        final parsed = SmsParser.parse(
          sender: message.address ?? '',
          body: message.body ?? '',
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            message.date ?? DateTime.now().millisecondsSinceEpoch,
          ),
        );
        
        if (parsed != null) {
          // Store and then notify the UI
          final savedTx = await TransactionDatabase().insertTransaction(parsed);
          _transactionStreamController.add(savedTx);
        }
      },
      onBackgroundMessage: backgroundMessageHandler,
    );
  }

  /// Imports existing financial SMS from the inbox.
  /// Optimized to only look back 30 days to save battery and memory.
  Future<int> importExistingInbox() async {
    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    final thirtyDaysAgo = now - (30 * 24 * 60 * 60 * 1000);

    List<TransactionModel> toImport = [];
    for (final message in messages) {
      final msgDate = message.date ?? 0;
      
      // Battery Optimization: Stop processing if we've reached messages older than 30 days
      if (msgDate < thirtyDaysAgo) break;

      final sender = message.address ?? '';
      final normalizedSender = sender.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
      
      bool isFinancial = false;
      for (var k in ParserPatterns.knownSenders) {
        if (normalizedSender.contains(k.replaceAll(RegExp(r'[\s-]'), ''))) {
          isFinancial = true;
          break;
        }
      }
      
      if (!isFinancial) continue;

      final parsed = SmsParser.parse(
        sender: sender,
        body: message.body ?? '',
        receivedAt: DateTime.fromMillisecondsSinceEpoch(msgDate),
      );
      
      if (parsed != null) {
        toImport.add(parsed);
      }
    }

    if (toImport.isNotEmpty) {
      await TransactionDatabase().insertTransactionsBatch(toImport);
    }
    
    return toImport.length;
  }
}