enum ForecastMethod { linear, exponentialWeighted, dayOfMonthPattern }

extension ForecastMethodLabel on ForecastMethod {
  String get label {
    switch (this) {
      case ForecastMethod.linear:
        return 'Linear day-rate';
      case ForecastMethod.exponentialWeighted:
        return 'Recent-day-weighted';
      case ForecastMethod.dayOfMonthPattern:
        return 'Typical month pattern';
    }
  }
}

class MonthlyProjection {
  final double spentSoFar;
  final double projectedTotal;
  final double confidenceLower;
  final double confidenceUpper;
  final int daysElapsed;
  final int daysInMonth;
  final ForecastMethod method;
  final double? backtestErrorPercent; // null if too little history to backtest

  const MonthlyProjection({
    required this.spentSoFar,
    required this.projectedTotal,
    required this.confidenceLower,
    required this.confidenceUpper,
    required this.daysElapsed,
    required this.daysInMonth,
    this.method = ForecastMethod.linear,
    this.backtestErrorPercent,
  });
}

class CategoryAnomaly {
  final String category;
  final double currentAmount;
  final double historicalAverage;

  const CategoryAnomaly({
    required this.category,
    required this.currentAmount,
    required this.historicalAverage,
  });

  double get percentAboveAverage =>
      historicalAverage == 0 ? 0 : ((currentAmount - historicalAverage) / historicalAverage) * 100;
}

class MonthlySummary {
  final String monthKey; // 'YYYY-MM'
  final DateTime monthStart;
  final double totalIn;
  final double totalOut;

  const MonthlySummary({
    required this.monthKey,
    required this.monthStart,
    required this.totalIn,
    required this.totalOut,
  });

  double get net => totalIn - totalOut;
}