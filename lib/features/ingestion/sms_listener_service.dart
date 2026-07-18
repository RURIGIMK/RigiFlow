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

/// Richer than a bool so the UI can tell "not yet asked" apart from
/// "denied but askable again" apart from "permanently denied — must
/// go to Settings" (Android only allows re-asking twice before this).
enum SmsPermissionState { granted, denied, permanentlyDenied }

class SmsListenerService {
  static final SmsListenerService _instance = SmsListenerService._internal();
  factory SmsListenerService() => _instance;
  SmsListenerService._internal();

  final Telephony _telephony = Telephony.instance;
  final _transactionStreamController = StreamController<TransactionModel>.broadcast();
  bool _isListening = false;
  bool _isImporting = false;

  static const int _maxMessagesToScan = 3000;
  static const Duration _importTimeBudget = Duration(seconds: 25);

  Stream<TransactionModel> get newTransactions => _transactionStreamController.stream;

  /// Requests via permission_handler — the reliable source of truth.
  /// telephony is used below purely for reading/listening to SMS, which
  /// works fine once the OS permission is granted through any path.
  Future<SmsPermissionState> requestPermissions() async {
    final status = await ph.Permission.sms.request();
    return _mapStatus(status);
  }

  /// Deliberately NOT cached — always reads Android's real, current
  /// permission state. This is the fix for the stale-cache bug: a
  /// permission granted later via system Settings is picked up
  /// correctly the very next time this is called.
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

  Future<int> importExistingInbox({
    void Function(ImportProgress progress)? onProgress,
  }) async {
    if (_isImporting) return 0;
    _isImporting = true;

    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - 1, 1);

      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE)
            .greaterThanOrEqualTo(startDate.millisecondsSinceEpoch.toString()),
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

        if (scanned % 15 == 0) {
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