import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../core/theme.dart';
import '../ingestion/models/transaction_model.dart';
import '../transactions/database/transaction_db.dart';
import 'sms_listener_service.dart';

class IngestionScreen extends StatefulWidget {
  const IngestionScreen({super.key});

  @override
  State<IngestionScreen> createState() => _IngestionScreenState();
}

class _IngestionScreenState extends State<IngestionScreen> {
  final SmsListenerService _smsService = SmsListenerService();
  final TransactionDatabase _db = TransactionDatabase();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _transactionSubscription;

  List<TransactionModel> _transactions = [];
  final Set<int> _newArrivalIds = {}; // Only these get the entrance animation

  bool _isChecking = true;
  bool _permissionsGranted = false;

  final int _pageSize = 30;
  bool _hasMore = true;
  bool _isFetchingMore = false;

  final _currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 2);
  final _dateFormat = DateFormat('d MMM, h:mm a');

  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      if (!_isFetchingMore && _hasMore) _loadMoreTransactions();
    }
  }

  Future<void> _initializeData() async {
    final granted = await _smsService.hasPermissions();
    await _loadFirstPage();
    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _permissionsGranted = granted;
    });
    if (granted) {
      _smsService.startListening();
      _listenForLiveTransactions();
    }
  }

  void _listenForLiveTransactions() {
    _transactionSubscription?.cancel();
    _transactionSubscription = _smsService.newTransactions.listen((tx) {
      if (mounted && tx.id != null) {
        setState(() {
          _transactions.insert(0, tx);
          _newArrivalIds.add(tx.id!);
        });
      }
    });
  }

  Future<void> _loadFirstPage() async {
    final txs = await _db.getTransactionsBefore(limit: _pageSize);
    if (!mounted) return;
    setState(() {
      _transactions = txs;
      _hasMore = txs.length == _pageSize;
    });
  }

  Future<void> _loadMoreTransactions() async {
    if (_isFetchingMore || !_hasMore || _transactions.isEmpty) return;
    setState(() => _isFetchingMore = true);

    final last = _transactions.last;
    final txs = await _db.getTransactionsBefore(
      beforeTimestamp: last.timestamp,
      beforeId: last.id,
      limit: _pageSize,
    );

    if (!mounted) return;
    setState(() {
      _transactions.addAll(txs);
      _hasMore = txs.length == _pageSize;
      _isFetchingMore = false;
    });
  }

  Future<void> _openAppSettingsForPermission() async {
    await ph.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [if (_permissionsGranted) const _LiveSyncIndicator()],
      ),
      body: Column(
        children: [
          if (!_isChecking && !_permissionsGranted)
            _PermissionDeniedBanner(onOpenSettings: _openAppSettingsForPermission),
          Expanded(
            child: _isChecking
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _transactions.isEmpty
                ? const _EmptyState()
                : ListView.builder(
              controller: _scrollController,
              cacheExtent: 1500,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _transactions.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _transactions.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final tx = _transactions[index];
                final isNew = tx.id != null && _newArrivalIds.contains(tx.id);
                return _TransactionTile(
                  key: ValueKey(tx.id ?? tx.rawSms.hashCode),
                  tx: tx,
                  isIn: tx.direction == TransactionDirection.moneyIn,
                  dateFormat: _dateFormat,
                  currencyFormat: _currencyFormat,
                  shouldAnimate: isNew,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatefulWidget {
  final TransactionModel tx;
  final bool isIn;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final bool shouldAnimate;

  const _TransactionTile({
    super.key,
    required this.tx,
    required this.isIn,
    required this.dateFormat,
    required this.currencyFormat,
    this.shouldAnimate = false,
  });

  @override
  State<_TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<_TransactionTile>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final content = RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.textMuted.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: (widget.isIn ? AppColors.flow : AppColors.alert).withOpacity(0.1),
              child: Icon(
                widget.isIn ? Icons.arrow_downward : Icons.arrow_upward,
                color: widget.isIn ? AppColors.flow : AppColors.alert,
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.tx.counterparty ?? widget.tx.source.name.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(widget.dateFormat.format(widget.tx.timestamp),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Text(
              '${widget.isIn ? '+' : '-'}${widget.currencyFormat.format(widget.tx.amount)}',
              style: AppTheme.amountStyle(
                size: 15,
                color: widget.isIn ? AppColors.flow : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.shouldAnimate) {
      return content.animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
    }
    return content;
  }
}

class _LiveSyncIndicator extends StatelessWidget {
  const _LiveSyncIndicator();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.flow.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: AppColors.flow, size: 14),
            const SizedBox(width: 4),
            Text('LIVE', style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.flow, fontWeight: FontWeight.bold,
            )),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
    );
  }
}

class _PermissionDeniedBanner extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _PermissionDeniedBanner({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.alert.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.alert),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('SMS access is off. Enable it in Settings to track transactions.'),
          ),
          TextButton(onPressed: onOpenSettings, child: const Text('Open')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textMuted.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('No transactions found.'),
        ],
      ),
    );
  }
}