import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../shared/widgets/flow_ribbon_background.dart';
import '../transactions/database/transaction_db.dart';
import 'forecasting_engine.dart';
import 'models/forecast_result.dart';
import 'monthly_reports_screen.dart';

class ForecastingScreen extends StatefulWidget {
  const ForecastingScreen({super.key});

  @override
  State<ForecastingScreen> createState() => _ForecastingScreenState();
}

class _ForecastingScreenState extends State<ForecastingScreen> {
  final TransactionDatabase _db = TransactionDatabase();
  final _currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);

  bool _loading = true;
  MonthlyProjection? _projection;
  Map<String, double> _categoryTotals = {};
  List<CategoryAnomaly> _anomalies = [];

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  Future<void> _loadForecast() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day;

    final currentDailyMap = await _db.getDailySpendTotals(start: monthStart, end: now);
    final currentMonthDaily = ForecastingEngine.orderedDailyList(
      dailyTotals: currentDailyMap,
      start: monthStart,
      days: daysElapsed,
    );

    // Up to the last 6 complete calendar months, each as an ordered
    // daily list — the backtesting engine's training ground.
    final historicalMonths = <List<double>>[];
    for (int i = 1; i <= 6; i++) {
      final histMonthStart = DateTime(now.year, now.month - i, 1);
      final histDaysInMonth = DateTime(now.year, now.month - i + 1, 0).day;
      final histMonthEnd = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59);

      final histDailyMap = await _db.getDailySpendTotals(start: histMonthStart, end: histMonthEnd);
      final histOrdered = ForecastingEngine.orderedDailyList(
        dailyTotals: histDailyMap,
        start: histMonthStart,
        days: histDaysInMonth,
      );
      if (histOrdered.any((v) => v > 0)) historicalMonths.add(histOrdered);
    }

    final projection = ForecastingEngine.backtestAndProject(
      historicalMonths: historicalMonths,
      currentMonthDaily: currentMonthDaily,
      daysInMonth: daysInMonth,
    );

    final categoryTotals = await _db.getCategoryTotals(start: monthStart, end: now);

    final historyStart = DateTime(now.year, now.month - 3, 1);
    final historicalAverages = await _db.getHistoricalCategoryAverages(
      historyStart: historyStart,
      historyEnd: monthStart,
      monthsSpanned: 3,
    );

    final anomalies = ForecastingEngine.detectAnomalies(
      currentMonthByCategory: categoryTotals,
      historicalAverageByCategory: historicalAverages,
    );

    if (!mounted) return;
    setState(() {
      _projection = projection;
      _categoryTotals = categoryTotals;
      _anomalies = anomalies;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_view_month),
            tooltip: 'Monthly Reports',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MonthlyReportsScreen()),
            ),
          ),
        ],
      ),
      body: FlowRibbonBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.flow))
            : RefreshIndicator(
          color: AppColors.flow,
          onRefresh: _loadForecast,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProjectionCard(projection: _projection!, currencyFormat: _currencyFormat)
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, end: 0),
              if (_anomalies.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Worth a look', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                ..._anomalies.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AnomalyTile(anomaly: a, currencyFormat: _currencyFormat),
                )),
              ],
              const SizedBox(height: 20),
              Text('This month by category', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              if (_categoryTotals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No spend recorded yet this month.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                )
              else
                _CategoryBreakdown(
                  categoryTotals: _categoryTotals,
                  currencyFormat: _currencyFormat,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  final MonthlyProjection projection;
  final NumberFormat currencyFormat;

  const _ProjectionCard({required this.projection, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final progress =
    projection.daysInMonth == 0 ? 0.0 : projection.daysElapsed / projection.daysInMonth;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Projected spend this month', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(projection.projectedTotal),
            style: AppTheme.amountStyle(size: 32, color: AppColors.flow),
          ),
          const SizedBox(height: 4),
          Text(
            '${currencyFormat.format(projection.confidenceLower)} – ${currencyFormat.format(projection.confidenceUpper)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.flow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              projection.backtestErrorPercent != null
                  ? '${projection.method.label} model • ~${projection.backtestErrorPercent!.toStringAsFixed(0)}% avg backtest error'
                  : '${projection.method.label} model • not enough history to backtest yet',
              style: const TextStyle(fontSize: 11, color: AppColors.flow),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.ink,
              valueColor: const AlwaysStoppedAnimation(AppColors.flow),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Day ${projection.daysElapsed} of ${projection.daysInMonth} • '
                '${currencyFormat.format(projection.spentSoFar)} spent so far',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AnomalyTile extends StatelessWidget {
  final CategoryAnomaly anomaly;
  final NumberFormat currencyFormat;

  const _AnomalyTile({required this.anomaly, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.alert.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.alert.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: AppColors.alert, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(anomaly.category,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${anomaly.percentAboveAverage.toStringAsFixed(0)}% above your usual '
                      '${currencyFormat.format(anomaly.historicalAverage)}/mo',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(currencyFormat.format(anomaly.currentAmount),
              style: AppTheme.amountStyle(size: 15, color: AppColors.alert)),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final Map<String, double> categoryTotals;
  final NumberFormat currencyFormat;

  const _CategoryBreakdown({required this.categoryTotals, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final total = categoryTotals.values.fold(0.0, (s, v) => s + v);
    final entries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: entries.map((entry) {
          final fraction = total == 0 ? 0.0 : entry.value / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(entry.key,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(currencyFormat.format(entry.value),
                        style: AppTheme.amountStyle(size: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: AppColors.ink,
                    valueColor: const AlwaysStoppedAnimation(AppColors.flow),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}