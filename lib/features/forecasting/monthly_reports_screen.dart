import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../shared/widgets/flow_ribbon_background.dart';
import '../transactions/database/transaction_db.dart';
import 'models/forecast_result.dart';

class MonthlyReportsScreen extends StatefulWidget {
  const MonthlyReportsScreen({super.key});

  @override
  State<MonthlyReportsScreen> createState() => _MonthlyReportsScreenState();
}

class _MonthlyReportsScreenState extends State<MonthlyReportsScreen> {
  final TransactionDatabase _db = TransactionDatabase();
  final _currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);
  final _monthFormat = DateFormat('MMMM yyyy');

  bool _loading = true;
  List<MonthlySummary> _summaries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summaries = await _db.getMonthlySummaries();
    if (!mounted) return;
    setState(() {
      _summaries = summaries.reversed.toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Reports')),
      body: FlowRibbonBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.flow))
            : _summaries.isEmpty
            ? Center(
          child: Text('No monthly data yet.',
              style: Theme.of(context).textTheme.bodyMedium),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _summaries.length,
          itemBuilder: (context, index) {
            final s = _summaries[index];
            final netPositive = s.net >= 0;
            return Container(
              key: ValueKey(s.monthKey),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_monthFormat.format(s.monthStart),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  // Equal-width columns is what actually fixes the
                  // misalignment — spaceBetween previously let each
                  // column's own content width push the numbers
                  // out of a shared grid.
                  Row(
                    children: [
                      Expanded(child: _statColumn(context, 'In', s.totalIn, AppColors.flow)),
                      Expanded(child: _statColumn(context, 'Out', s.totalOut, AppColors.alert)),
                      Expanded(
                        child: _statColumn(context, 'Net', s.net,
                            netPositive ? AppColors.flow : AppColors.alert),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ).animate().fadeIn(duration: 350.ms),
      ),
    );
  }

  Widget _statColumn(BuildContext context, String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        // Shrinks rather than overflows on narrow screens or with large
        // figures — the other half of the "fits on all phones" fix.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(_currencyFormat.format(value), style: AppTheme.amountStyle(size: 15, color: color)),
        ),
      ],
    );
  }
}