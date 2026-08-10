class MonthlyProjection {
  final double spentSoFar;
  final double projectedTotal;
  final double confidenceLower;
  final double confidenceUpper;
  final int daysElapsed;
  final int daysInMonth;

  const MonthlyProjection({
    required this.spentSoFar,
    required this.projectedTotal,
    required this.confidenceLower,
    required this.confidenceUpper,
    required this.daysElapsed,
    required this.daysInMonth,
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