import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
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
  final Set<int> _displayedIds = {}; // Track IDs to prevent duplicates
  
  bool _isLoading = false;
  bool _isChecking = true;
  bool _permissionsGranted = false;
  
  int _offset = 0;
  final int _limit = 50;
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
    // Optimization: Start fetching more items much earlier (500px buffer)
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      if (!_isFetchingMore && _hasMore) {
        _loadMoreTransactions();
      }
    }
  }

  Future<void> _initializeData() async {
    try {
      await _loadInitialTransactions();
      final granted = await _smsService.hasPermissions();
      if (mounted) {
        setState(() {
          _isChecking = false;
          if (granted) {
            _permissionsGranted = true;
            _startLiveStream();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _startLiveStream() {
    _smsService.startListening();
    _transactionSubscription?.cancel();
    _transactionSubscription = _smsService.newTransactions.listen((tx) {
      if (mounted && tx.id != null && !_displayedIds.contains(tx.id)) {
        setState(() {
          _transactions.insert(0, tx);
          _displayedIds.add(tx.id!);
          _offset++; 
        });
      }
    });
  }

  Future<void> _loadInitialTransactions() async {
    try {
      final txs = await _db.getTransactions(limit: _limit, offset: 0);
      if (!mounted) return;
      setState(() {
        _transactions = txs;
        _displayedIds.addAll(txs.where((t) => t.id != null).map((t) => t.id!));
        _offset = txs.length;
        _hasMore = txs.length == _limit;
      });
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_isFetchingMore || !_hasMore) return;
    setState(() => _isFetchingMore = true);
    try {
      final txs = await _db.getTransactions(limit: _limit, offset: _offset);
      if (!mounted) return;
      setState(() {
        // Only add transactions we don't already have in memory
        for (var tx in txs) {
          if (tx.id != null && !_displayedIds.contains(tx.id)) {
            _transactions.add(tx);
            _displayedIds.add(tx.id!);
          }
        }
        _offset += txs.length;
        _hasMore = txs.length == _limit;
        _isFetchingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  Future<void> _requestPermissionsAndSync() async {
    setState(() => _isLoading = true);
    try {
      final granted = await _smsService.requestPermissions();
      if (!mounted) return;

      if (!granted) {
        setState(() => _isLoading = false);
        return;
      }

      await _smsService.importExistingInbox();
      await _loadInitialTransactions();
      
      if (mounted) {
        setState(() {
          _permissionsGranted = true;
          _isLoading = false;
        });
        _startLiveStream();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          if (_permissionsGranted) const _LiveSyncIndicator(),
        ],
      ),
      body: Column(
        children: [
          if (!_isChecking && !_permissionsGranted)
            _ConnectButton(
              isLoading: _isLoading,
              onPressed: _requestPermissionsAndSync,
            ),
          
          Expanded(
            child: _isChecking 
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _transactions.isEmpty && !_isLoading
                ? const _EmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    // PERFORMANCE: High cache extent ensures top items stay in memory when you scroll down
                    cacheExtent: 2500, 
                    addAutomaticKeepAlives: true,
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
                      return _TransactionTile(
                        key: ValueKey(tx.id), // Stable key based on DB ID
                        tx: tx,
                        isIn: tx.direction == TransactionDirection.moneyIn,
                        dateFormat: _dateFormat,
                        currencyFormat: _currencyFormat,
                        // Only animate if it's the very first time we've seen this item in the list
                        shouldAnimate: index == 0 && _transactions.length > _limit,
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

class _TransactionTileState extends State<_TransactionTile> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Prevents "disappearing" on scroll

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
                color: widget.isIn ? AppColors.flow : AppColors.textPrimary
              ),
            ),
          ],
        ),
      ),
    );

    // Only apply animation for new arrivals, otherwise render immediately
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
              color: AppColors.flow, fontWeight: FontWeight.bold
            )),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _ConnectButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading 
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.sms_outlined),
        label: Text(isLoading ? 'Syncing...' : 'Connect SMS Auto-Tracking'),
      ).animate().fadeIn().slideY(begin: -0.2, end: 0),
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