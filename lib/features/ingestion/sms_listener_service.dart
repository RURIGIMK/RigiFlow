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

/// Reported during import so the UI can show real progress.
class ImportProgress {
  final int scanned;
  final int total;
  final int matched;
  const ImportProgress({required this.scanned, required this.total, required this.matched});
  double get fraction => total == 0 ? 0 : scanned / total;
}

class SmsListenerService {
  static final SmsListenerService _instance = SmsListenerService._internal();
  factory SmsListenerService() => _instance;
  SmsListenerService._internal();

  final Telephony _telephony = Telephony.instance;
  final _transactionStreamController = StreamController<TransactionModel>.broadcast();
  bool _isListening = false;
  bool _isImporting = false; // loop preventor: blocks re-entrant import calls

  bool? _cachedPermissionStatus;

  // Loop preventors — defense in depth even though the native date
  // filter should already keep message counts small.
  static const int _maxMessagesToScan = 3000;
  static const Duration _importTimeBudget = Duration(seconds: 25);

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

  /// Imports SMS from the 1st of last month through today — e.g. run in
  /// mid-July, this pulls June 1st onward. Reports live progress and is
  /// guarded against runaway loops on unusually large inboxes.
  Future<int> importExistingInbox({
    void Function(ImportProgress progress)? onProgress,
  }) async {
    if (_isImporting) return 0; // reentrancy guard
    _isImporting = true;

    try {
      final now = DateTime.now();
      // Dart's DateTime normalizes month=0 to December of the prior year,
      // so this correctly rolls back across a year boundary too.
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

        // Loop preventor 1: hard cap regardless of what the filter returned.
        if (scanned > _maxMessagesToScan) break;
        // Loop preventor 2: time-boxed — stop cleanly and keep partial results.
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
          // Loop preventor 3: one malformed message never stalls the batch.
          continue;
        }

        // Yield to the UI thread periodically so the progress bar actually
        // animates instead of the app looking frozen mid-import.
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