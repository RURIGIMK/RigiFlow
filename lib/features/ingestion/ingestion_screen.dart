import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../core/theme.dart';
import '../ingestion/models/transaction_model.dart';
import '../transactions/database/transaction_db.dart';
import '../transactions/models/category.dart';
import 'sms_listener_service.dart';

enum _DirectionFilter { all, inOnly, outOnly }

class IngestionScreen extends StatefulWidget {
  const IngestionScreen({super.key});

  @override
  State<IngestionScreen> createState() => _IngestionScreenState();
}

class _IngestionScreenState extends State<IngestionScreen>
    with WidgetsBindingObserver {
  final SmsListenerService _smsService = SmsListenerService();
  final TransactionDatabase _db = TransactionDatabase();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _transactionSubscription;

  List<TransactionModel> _transactions = [];
  final Set<int> _newArrivalIds = {};

  bool _isChecking = true;
  SmsPermissionState _permissionState = SmsPermissionState.denied;

  final int _pageSize = 30;
  bool _hasMore = true;
  bool _isFetchingMore = false;

  _DirectionFilter _directionFilter = _DirectionFilter.all;
  DateTimeRange? _dateRangeFilter;

  final _currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 2);
  final _dateFormat = DateFormat('d MMM, h:mm a');
  final _rangeFormat = DateFormat('d MMM');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transactionSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckPermissionOnResume();
    }
  }

  Future<void> _recheckPermissionOnResume() async {
    final wasGranted = _permissionState == SmsPermissionState.granted;
    final newState = await _smsService.checkPermissionStatus();
    if (!mounted) return;

    setState(() => _permissionState = newState);

    final nowGranted = newState == SmsPermissionState.granted;
    if (!wasGranted && nowGranted) {
      _smsService.startListening();
      await _smsService.importExistingInbox();
      await _loadFirstPage();
      _listenForLiveTransactions();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      if (!_isFetchingMore && _hasMore) _loadMoreTransactions();
    }
  }

  Future<void> _initializeData() async {
    try {
      final state = await _smsService
          .checkPermissionStatus()
          .timeout(const Duration(seconds: 5), onTimeout: () => SmsPermissionState.denied);

      await _loadFirstPage().timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _permissionState = state;
      });

      if (state == SmsPermissionState.granted) {
        _listenForLiveTransactions();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _permissionState = SmsPermissionState.denied;
      });
    }
  }

  TransactionDirection? get _directionArg {
    switch (_directionFilter) {
      case _DirectionFilter.inOnly:
        return TransactionDirection.moneyIn;
      case _DirectionFilter.outOnly:
        return TransactionDirection.moneyOut;
      case _DirectionFilter.all:
        return null;
    }
  }

  void _listenForLiveTransactions() {
    _transactionSubscription?.cancel();
    _transactionSubscription = _smsService.newTransactions.listen((tx) {
      if (!mounted || tx.id == null) return;
      if (_directionArg != null && tx.direction != _directionArg) return;
      setState(() {
        _transactions.insert(0, tx);
        _newArrivalIds.add(tx.id!);
      });
    });
  }

  Future<void> _loadFirstPage() async {
    final txs = await _db.getFilteredTransactions(
      direction: _directionArg,
      startDate: _dateRangeFilter?.start,
      endDate: _dateRangeFilter?.end,
      limit: _pageSize,
    );
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
    final txs = await _db.getFilteredTransactions(
      direction: _directionArg,
      startDate: _dateRangeFilter?.start,
      endDate: _dateRangeFilter?.end,
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

  void _setDirectionFilter(_DirectionFilter filter) {
    setState(() => _directionFilter = filter);
    _loadFirstPage();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final earliestSelectable = DateTime(now.year - 15);

    final startDate = await showDatePicker(
      context: context,
      helpText: 'Select start date',
      initialDate: _dateRangeFilter?.start ?? now,
      firstDate: earliestSelectable,
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendar,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.flow,
            onPrimary: AppColors.ink,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (startDate == null || !mounted) return;

    final endDate = await showDatePicker(
      context: context,
      helpText: 'Select end date',
      initialDate: _dateRangeFilter?.end ?? now,
      firstDate: startDate,
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendar,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.flow,
            onPrimary: AppColors.ink,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (endDate == null || !mounted) return;

    setState(() => _dateRangeFilter = DateTimeRange(start: startDate, end: endDate));
    _loadFirstPage();
  }

  void _clearDateRange() {
    setState(() => _dateRangeFilter = null);
    _loadFirstPage();
  }

  Future<void> _retryPermissionRequest() async {
    final state = await _smsService.requestPermissions();
    if (!mounted) return;
    setState(() => _permissionState = state);
    if (state == SmsPermissionState.granted) {
      _smsService.startListening();
      await _smsService.importExistingInbox();
      await _loadFirstPage();
      _listenForLiveTransactions();
    }
  }

  Future<void> _openAppSettingsForPermission() async {
    await ph.openAppSettings();
  }

  /// Opens the full transaction detail sheet. If the person changes the
  /// category from within it (nested category-picker sheet), the detail
  /// sheet pops back here with the new category name, which we persist
  /// and reflect in the list — same end effect as the old direct
  /// category-picker tap, just reached via the detail view now.
  Future<void> _openTransactionDetail(TransactionModel tx) async {
    final newCategory = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _TransactionDetailSheet(tx: tx, currencyFormat: _currencyFormat),
    );
    if (newCategory == null || newCategory == tx.category || tx.id == null) return;

    await _db.updateCategory(tx.id!, newCategory);
    if (!mounted) return;
    setState(() {
      final index = _transactions.indexWhere((t) => t.id == tx.id);
      if (index != -1) {
        _transactions[index] = _transactions[index].copyWith(category: newCategory);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final granted = _permissionState == SmsPermissionState.granted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [if (granted) const _LiveSyncIndicator()],
      ),
      body: Column(
        children: [
          if (!_isChecking && !granted)
            _PermissionBanner(
              permanentlyDenied: _permissionState == SmsPermissionState.permanentlyDenied,
              onRetry: _retryPermissionRequest,
              onOpenSettings: _openAppSettingsForPermission,
            ),
          _FilterBar(
            directionFilter: _directionFilter,
            dateRangeLabel: _dateRangeFilter == null
                ? null
                : '${_rangeFormat.format(_dateRangeFilter!.start)} – ${_rangeFormat.format(_dateRangeFilter!.end)}',
            onDirectionChanged: _setDirectionFilter,
            onPickDateRange: _pickDateRange,
            onClearDateRange: _clearDateRange,
          ),
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
                  onTap: () => _openTransactionDetail(tx),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _DirectionFilter directionFilter;
  final String? dateRangeLabel;
  final void Function(_DirectionFilter) onDirectionChanged;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;

  const _FilterBar({
    required this.directionFilter,
    required this.dateRangeLabel,
    required this.onDirectionChanged,
    required this.onPickDateRange,
    required this.onClearDateRange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip('All', directionFilter == _DirectionFilter.all,
                    () => onDirectionChanged(_DirectionFilter.all)),
            const SizedBox(width: 8),
            _chip('In', directionFilter == _DirectionFilter.inOnly,
                    () => onDirectionChanged(_DirectionFilter.inOnly)),
            const SizedBox(width: 8),
            _chip('Out', directionFilter == _DirectionFilter.outOnly,
                    () => onDirectionChanged(_DirectionFilter.outOnly)),
            const SizedBox(width: 12),
            ActionChip(
              backgroundColor: AppColors.surface,
              avatar: Icon(Icons.calendar_today,
                  size: 15,
                  color: dateRangeLabel == null ? AppColors.textMuted : AppColors.flow),
              label: Text(dateRangeLabel ?? 'Date range'),
              onPressed: onPickDateRange,
            ),
            if (dateRangeLabel != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                onPressed: onClearDateRange,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.flow,
      labelStyle: TextStyle(color: selected ? AppColors.ink : AppColors.textPrimary),
    );
  }
}

class _CategoryPickerSheet extends StatelessWidget {
  final String currentCategory;
  const _CategoryPickerSheet({required this.currentCategory});

  IconData _iconFor(String name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'phone_android':
        return Icons.phone_android;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'home':
        return Icons.home;
      case 'savings':
        return Icons.savings;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'movie':
        return Icons.movie;
      case 'school':
        return Icons.school;
      case 'people':
        return Icons.people;
      case 'payments':
        return Icons.payments;
      case 'account_balance':
        return Icons.account_balance;
      case 'toll':
        return Icons.toll;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.6;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text('Choose a category', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: Categories.all.map((c) {
                  final selected = c.name == currentCategory;
                  return ListTile(
                    leading: Icon(_iconFor(c.icon),
                        color: selected ? AppColors.flow : AppColors.textMuted),
                    title: Text(c.name,
                        style: TextStyle(
                            color: selected ? AppColors.flow : AppColors.textPrimary,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                    trailing: selected ? const Icon(Icons.check, color: AppColors.flow) : null,
                    onTap: () => Navigator.of(context).pop(c.name),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full transaction detail — deliberately built from the structured
/// fields we actually store, never the raw SMS text. That's what keeps
/// balance out automatically: we never parse or store it in the first
/// place, so there's nothing to redact. Wrapped in a scroll view so it
/// never overflows regardless of screen height or accessibility text
/// scaling.
class _TransactionDetailSheet extends StatefulWidget {
  final TransactionModel tx;
  final NumberFormat currencyFormat;
  const _TransactionDetailSheet({required this.tx, required this.currencyFormat});

  @override
  State<_TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<_TransactionDetailSheet> {
  late TransactionModel _tx;

  @override
  void initState() {
    super.initState();
    _tx = widget.tx;
  }

  Future<void> _changeCategory() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CategoryPickerSheet(currentCategory: _tx.category),
    );
    if (selected == null || selected == _tx.category || !mounted) return;
    Navigator.of(context).pop(selected); // hand the new category to the caller
  }

  Widget _row(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
            child: Text(value,
                style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIn = _tx.direction == TransactionDirection.moneyIn;
    final dateTimeFormat = DateFormat('EEEE, d MMMM yyyy • h:mm a');

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Transaction Details', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${isIn ? '+' : '-'}${widget.currencyFormat.format(_tx.amount)}',
                style: AppTheme.amountStyle(size: 26, color: isIn ? AppColors.flow : AppColors.alert),
              ),
            ),
            const Divider(height: 32, color: AppColors.textMuted),
            _row(context, 'To/From', _tx.counterparty ?? _tx.source.name.toUpperCase()),
            _row(context, 'Direction', isIn ? 'Money In' : 'Money Out'),
            _row(context, 'Date', dateTimeFormat.format(_tx.timestamp)),
            _row(context, 'Source', _tx.source.name.toUpperCase()),
            if (_tx.transactionCode != null) _row(context, 'Reference', _tx.transactionCode!),
            InkWell(
              onTap: _changeCategory,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox(width: 96, child: Text('Category', style: Theme.of(context).textTheme.bodySmall)),
                    Expanded(
                      child: Text(_tx.category,
                          style: const TextStyle(color: AppColors.flow, fontWeight: FontWeight.w600)),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
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
  final VoidCallback onTap;

  const _TransactionTile({
    super.key,
    required this.tx,
    required this.isIn,
    required this.dateFormat,
    required this.currencyFormat,
    required this.onTap,
    this.shouldAnimate = false,
  });

  @override
  State<_TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<_TransactionTile>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool get _isSavings => widget.tx.category == 'Savings';

  Color get _accentColor {
    if (_isSavings) {
      return widget.isIn ? AppColors.alert : AppColors.flow;
    }
    return widget.isIn ? AppColors.flow : AppColors.alert;
  }

  Color get _amountColor {
    if (_isSavings) {
      return widget.isIn ? AppColors.alert : AppColors.flow;
    }
    return widget.isIn ? AppColors.flow : AppColors.textPrimary;
  }

  String get _categoryLine {
    if (_isSavings) {
      return widget.isIn ? 'Savings withdrawal' : 'Savings deposit';
    }
    return widget.tx.category;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final content = RepaintBoundary(
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.textMuted.withOpacity(0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: _accentColor.withOpacity(0.1),
                child: Icon(
                  widget.isIn ? Icons.arrow_downward : Icons.arrow_upward,
                  color: _accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              // Full name, up to 2 lines — no longer truncated to one
              // line — then category and date as their own separate
              // lines, per the requested 3-line layout.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tx.counterparty ?? widget.tx.source.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(_categoryLine,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(widget.dateFormat.format(widget.tx.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted.withOpacity(0.7)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Shrinks rather than overflows on narrow screens or with
              // unusually large amounts.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${widget.isIn ? '+' : '-'}${widget.currencyFormat.format(widget.tx.amount)}',
                    style: AppTheme.amountStyle(size: 15, color: _amountColor),
                  ),
                ),
              ),
            ],
          ),
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

class _PermissionBanner extends StatelessWidget {
  final bool permanentlyDenied;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  const _PermissionBanner({
    required this.permanentlyDenied,
    required this.onRetry,
    required this.onOpenSettings,
  });

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
          Expanded(
            child: Text(
              permanentlyDenied
                  ? 'SMS access was denied. Enable it in Settings to track transactions.'
                  : 'SMS access is needed to track transactions.',
            ),
          ),
          TextButton(
            onPressed: permanentlyDenied ? onOpenSettings : onRetry,
            child: Text(permanentlyDenied ? 'Open' : 'Grant'),
          ),
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