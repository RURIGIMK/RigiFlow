import 'dart:async';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'parsing/sms_parser.dart';
import 'parsing/parser_patterns.dart';
import '../transactions/database/transaction_db.dart';
import '../ingestion/models/transaction_model.dart';

@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
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
  await db.close();
}

class ImportProgress {
  final int scanned;
  final int total;
  final int matched;
  const ImportProgress({required this.scanned, required this.total, required this.matched});
  double get fraction => total == 0 ? 0 : scanned / total;
}

enum SmsPermissionState { granted, denied, permanentlyDenied }

class SmsListenerService {
  static final SmsListenerService _instance = SmsListenerService._internal();
  factory SmsListenerService() => _instance;
  SmsListenerService._internal();

  final Telephony _telephony = Telephony.instance;
  final _transactionStreamController = StreamController<TransactionModel>.broadcast();
  bool _isListening = false;
  bool _isImporting = false;

  // Raised from the original 30-day-window sizing (3000 / 25s) to
  // accommodate scanning a full multi-year inbox now that there's no
  // date cutoff — regex scanning itself is fast (the earlier hang was
  // a database bug, already fixed), so this is a generous safety net,
  // not an expected bottleneck.
  static const int _maxMessagesToScan = 20000;
  static const Duration _importTimeBudget = Duration(seconds: 90);

  Stream<TransactionModel> get newTransactions => _transactionStreamController.stream;

  Future<SmsPermissionState> requestPermissions() async {
    final status = await ph.Permission.sms.request();
    return _mapStatus(status);
  }

  Future<SmsPermissionState> checkPermissionStatus() async {
    final status = await ph.Permission.sms.status;
    return _mapStatus(status);
  }

  SmsPermissionState _mapStatus(ph.PermissionStatus status) {
    if (status.isGranted) return SmsPermissionState.granted;
    if (status.isPermanentlyDenied) return SmsPermissionState.permanentlyDenied;
    return SmsPermissionState.denied;
  }

  Future<bool> requestBatteryOptimizationExemption() async {
    final status = await ph.Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return true;
    final result = await ph.Permission.ignoreBatteryOptimizations.request();
    return result.isGranted;
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
          final savedTx = await TransactionDatabase().insertTransaction(parsed);
          _transactionStreamController.add(savedTx);
        }
      },
      onBackgroundMessage: backgroundMessageHandler,
    );
  }

  /// Imports the FULL SMS inbox history available on the device — no
  /// date cutoff. How far back this actually reaches is bounded by
  /// whatever the phone's own SMS app has retained (some phones/OEMs
  /// periodically prune very old SMS for storage) — not something the
  /// app can control beyond reading whatever's still there.
  Future<int> importExistingInbox({
    void Function(ImportProgress progress)? onProgress,
  }) async {
    if (_isImporting) return 0;
    _isImporting = true;

    try {
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      final total = messages.length;
      int scanned = 0;
      int matched = 0;
      final stopwatch = Stopwatch()..start();
      final List<TransactionModel> toImport = [];

      for (final message in messages) {
        scanned++;
        if (scanned > _maxMessagesToScan) break;
        if (stopwatch.elapsed > _importTimeBudget) break;

        try {
          final sender = message.address ?? '';
          final normalizedSender = sender.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

          bool isFinancial = false;
          for (var k in ParserPatterns.knownSenders) {
            if (normalizedSender.contains(k.replaceAll(RegExp(r'[\s-]'), ''))) {
              isFinancial = true;
              break;
            }
          }

          if (isFinancial) {
            final parsed = SmsParser.parse(
              sender: sender,
              body: message.body ?? '',
              receivedAt: DateTime.fromMillisecondsSinceEpoch(message.date ?? 0),
            );
            if (parsed != null) {
              toImport.add(parsed);
              matched++;
            }
          }
        } catch (_) {
          continue;
        }

        if (scanned % 25 == 0) {
          onProgress?.call(ImportProgress(scanned: scanned, total: total, matched: matched));
          await Future.delayed(Duration.zero);
        }
      }

      onProgress?.call(ImportProgress(scanned: scanned, total: total, matched: matched));

      if (toImport.isNotEmpty) {
        await TransactionDatabase().insertTransactionsBatch(toImport);
      }
      return matched;
    } finally {
      _isImporting = false;
    }
  }
}