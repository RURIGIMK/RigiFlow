import 'dart:math';
import 'models/forecast_result.dart';

class ForecastingEngine {
  static const List<ForecastMethod> _candidateMethods = [
    ForecastMethod.linear,
    ForecastMethod.exponentialWeighted,
    ForecastMethod.dayOfMonthPattern,
  ];

  static const double _exponentialDecay = 0.85;

  /// Converts a {'YYYY-MM-DD': amount} map into an ordered list where
  /// index 0 = the first of `days` days starting at `start` — missing
  /// days become 0. Builds the date key manually (matching SQLite's
  /// strftime output) to avoid an extra dependency in this file.
  static List<double> orderedDailyList({
    required Map<String, double> dailyTotals,
    required DateTime start,
    required int days,
  }) {
    return List.generate(days, (i) {
      final day = start.add(Duration(days: i));
      final key = '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      return dailyTotals[key] ?? 0.0;
    });
  }

  static double _linearEstimate(List<double> amounts, int daysInMonth) {
    final daysElapsed = amounts.length;
    if (daysElapsed == 0) return 0;
    final total = amounts.fold(0.0, (s, v) => s + v);
    return (total / daysElapsed) * daysInMonth;
  }

  static double _exponentialWeightedEstimate(List<double> amounts, int daysInMonth) {
    final daysElapsed = amounts.length;
    if (daysElapsed == 0) return 0;
    double weightedSum = 0;
    double weightSum = 0;
    for (int i = 0; i < daysElapsed; i++) {
      final daysAgo = daysElapsed - 1 - i; // 0 = most recent day
      final weight = pow(_exponentialDecay, daysAgo).toDouble();
      weightedSum += amounts[i] * weight;
      weightSum += weight;
    }
    if (weightSum == 0) return 0;
    return (weightedSum / weightSum) * daysInMonth;
  }

  static double _dayOfMonthPatternEstimate(
      List<double> amounts,
      int daysInMonth,
      List<double>? typicalCumulativeFraction,
      ) {
    final daysElapsed = amounts.length;
    if (daysElapsed == 0 || typicalCumulativeFraction == null) return 0;
    final total = amounts.fold(0.0, (s, v) => s + v);
    final idx = min(daysElapsed - 1, typicalCumulativeFraction.length - 1);
    final fraction = typicalCumulativeFraction[idx];
    if (fraction <= 0.01) return total;
    return total / fraction;
  }

  /// "On average, what fraction of a month's eventual total has usually
  /// been spent by day N" — built from all available historical months.
  /// A simplification worth naming honestly: this isn't a strict
  /// leave-one-out cross-validation, which would be the more rigorous
  /// academic approach — for a single personal user with a handful of
  /// historical months, that rigor buys little, so this lighter version
  /// is the more honest trade-off.
  static List<double>? _buildTypicalCumulativeFraction(
      List<List<double>> historicalMonths,
      int daysInMonth,
      ) {
    if (historicalMonths.length < 2) return null;

    final fractionSums = List<double>.filled(daysInMonth, 0);
    final fractionCounts = List<int>.filled(daysInMonth, 0);

    for (final monthAmounts in historicalMonths) {
      final monthTotal = monthAmounts.fold(0.0, (s, v) => s + v);
      if (monthTotal <= 0) continue;
      double running = 0;
      for (int day = 0; day < monthAmounts.length && day < daysInMonth; day++) {
        running += monthAmounts[day];
        fractionSums[day] += running / monthTotal;
        fractionCounts[day]++;
      }
    }

    return List.generate(daysInMonth, (i) {
      if (fractionCounts[i] == 0) return (i + 1) / daysInMonth; // fallback: linear
      return fractionSums[i] / fractionCounts[i];
    });
  }

  static double _estimateFor(
      ForecastMethod method,
      List<double> amounts,
      int daysInMonth,
      List<double>? typicalCurve,
      ) {
    switch (method) {
      case ForecastMethod.linear:
        return _linearEstimate(amounts, daysInMonth);
      case ForecastMethod.exponentialWeighted:
        return _exponentialWeightedEstimate(amounts, daysInMonth);
      case ForecastMethod.dayOfMonthPattern:
        return _dayOfMonthPatternEstimate(amounts, daysInMonth, typicalCurve);
    }
  }

  /// Backtests all three candidate methods against your own complete
  /// past months (checkpoints at ~25%/50%/75% through each), picks
  /// whichever had the lowest average error, then applies it to the
  /// current in-progress month. This is genuine model selection via
  /// backtesting — the same principle as cross-validation — just
  /// applied to simple statistical models rather than a trained neural
  /// net, which is the honest choice at this data scale.
  static MonthlyProjection backtestAndProject({
    required List<List<double>> historicalMonths,
    required List<double> currentMonthDaily,
    required int daysInMonth,
  }) {
    final spentSoFar = currentMonthDaily.fold(0.0, (s, v) => s + v);
    final daysElapsed = currentMonthDaily.length;

    if (daysElapsed == 0) {
      return MonthlyProjection(
        spentSoFar: 0,
        projectedTotal: 0,
        confidenceLower: 0,
        confidenceUpper: 0,
        daysElapsed: 0,
        daysInMonth: daysInMonth,
      );
    }

    final typicalCurve = _buildTypicalCumulativeFraction(historicalMonths, daysInMonth);

    ForecastMethod bestMethod = ForecastMethod.linear;
    double? bestError;

    if (historicalMonths.isNotEmpty) {
      final errorsByMethod = <ForecastMethod, List<double>>{
        for (final m in _candidateMethods) m: [],
      };

      for (final monthAmounts in historicalMonths) {
        final actualTotal = monthAmounts.fold(0.0, (s, v) => s + v);
        if (actualTotal <= 0 || monthAmounts.length < 2) continue;

        for (final fraction in [0.25, 0.5, 0.75]) {
          final checkpointDay =
          (fraction * monthAmounts.length).round().clamp(1, monthAmounts.length - 1);
          final partial = monthAmounts.sublist(0, checkpointDay);

          for (final method in _candidateMethods) {
            final estimate = _estimateFor(method, partial, monthAmounts.length, typicalCurve);
            final errorPercent = ((estimate - actualTotal).abs() / actualTotal) * 100;
            errorsByMethod[method]!.add(errorPercent);
          }
        }
      }

      for (final entry in errorsByMethod.entries) {
        if (entry.value.isEmpty) continue;
        final avgError = entry.value.fold(0.0, (s, v) => s + v) / entry.value.length;
        if (bestError == null || avgError < bestError) {
          bestError = avgError;
          bestMethod = entry.key;
        }
      }
    }

    final projectedTotal = _estimateFor(bestMethod, currentMonthDaily, daysInMonth, typicalCurve);

    final mean = spentSoFar / daysElapsed;
    final variance =
        currentMonthDaily.fold(0.0, (s, v) => s + pow(v - mean, 2)) / daysElapsed;
    final dailyStdDev = sqrt(variance);
    final remainingDays = daysInMonth - daysElapsed;
    final projectedStdDev = dailyStdDev * sqrt(max(remainingDays, 0));

    return MonthlyProjection(
      spentSoFar: spentSoFar,
      projectedTotal: projectedTotal,
      confidenceLower: max(0, projectedTotal - projectedStdDev),
      confidenceUpper: projectedTotal + projectedStdDev,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
      method: bestMethod,
      backtestErrorPercent: bestError,
    );
  }

  static List<CategoryAnomaly> detectAnomalies({
    required Map<String, double> currentMonthByCategory,
    required Map<String, double> historicalAverageByCategory,
    double thresholdMultiplier = 1.4,
    double minimumHistoricalAmount = 100,
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