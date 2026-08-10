import 'dart:math';
import 'models/forecast_result.dart';

class ForecastingEngine {
  /// Projects the end-of-month total from spend so far this month, using
  /// a daily-rate extrapolation with a confidence band derived from the
  /// day-to-day variance actually observed — pure on-device statistics,
  /// no ML model, no network call.
  static MonthlyProjection projectMonthEnd({
    required Map<String, double> dailyTotals, // 'YYYY-MM-DD' -> amount
    required int daysElapsed,
    required int daysInMonth,
  }) {
    final amounts = dailyTotals.values.toList();
    final spentSoFar = amounts.fold(0.0, (sum, v) => sum + v);

    if (daysElapsed == 0 || amounts.isEmpty) {
      return MonthlyProjection(
        spentSoFar: 0,
        projectedTotal: 0,
        confidenceLower: 0,
        confidenceUpper: 0,
        daysElapsed: daysElapsed,
        daysInMonth: daysInMonth,
      );
    }

    final dailyAverage = spentSoFar / daysElapsed;
    final projectedTotal = dailyAverage * daysInMonth;

    final mean = amounts.fold(0.0, (s, v) => s + v) / amounts.length;
    final variance = amounts.fold(0.0, (s, v) => s + pow(v - mean, 2)) / amounts.length;
    final dailyStdDev = sqrt(variance);

    final remainingDays = daysInMonth - daysElapsed;
    // Variance of a sum of independent daily draws scales with the
    // number of days remaining; std dev scales with its square root.
    final projectedStdDev = dailyStdDev * sqrt(max(remainingDays, 0));

    return MonthlyProjection(
      spentSoFar: spentSoFar,
      projectedTotal: projectedTotal,
      confidenceLower: max(0, projectedTotal - projectedStdDev),
      confidenceUpper: projectedTotal + projectedStdDev,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
    );
  }

  /// Flags categories where this month's spend is meaningfully above its
  /// trailing historical average. Deliberately uses a percentage
  /// threshold rather than a z-score — a brand-new app has too little
  /// historical depth for variance-based statistics to be reliable, so
  /// this is the more honest choice given the real data constraints.
  static List<CategoryAnomaly> detectAnomalies({
    required Map<String, double> currentMonthByCategory,
    required Map<String, double> historicalAverageByCategory,
    double thresholdMultiplier = 1.4, // 40% above historical average
    double minimumHistoricalAmount = 100, // ignore trivially small categories
  }) {
    final anomalies = <CategoryAnomaly>[];

    for (final entry in currentMonthByCategory.entries) {
      final category = entry.key;
      final currentAmount = entry.value;
      final historicalAverage = historicalAverageByCategory[category] ?? 0;

      if (historicalAverage < minimumHistoricalAmount) continue;
      if (currentAmount > historicalAverage * thresholdMultiplier) {
        anomalies.add(CategoryAnomaly(
          category: category,
          currentAmount: currentAmount,
          historicalAverage: historicalAverage,
        ));
      }
    }

    anomalies.sort((a, b) => b.percentAboveAverage.compareTo(a.percentAboveAverage));
    return anomalies;
  }
}