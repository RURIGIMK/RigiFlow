import '../models/category.dart';

/// Maps a counterparty/merchant name to a category by keyword match.
/// Runs once at parse time; the user's manual corrections (stored per
/// transaction_code in the DB) always take precedence over this on
/// re-categorization.
class CategoryRules {
  static const Map<String, List<String>> _keywordMap = {
    'Food & Groceries': [
      'NAIVAS', 'CARREFOUR', 'QUICKMART', 'CHANDARANA', 'TUSKYS',
      'SUPERMARKET', 'BUTCHERY', 'RESTAURANT', 'CAFE', 'HOTEL',
      'KFC', 'JAVA', 'PIZZA', 'FOOD',
    ],
    'Transport': [
      'UBER', 'BOLT', 'LITTLE CAB', 'MATATU', 'SGR', 'SHELL', 'TOTAL',
      'RUBIS', 'PETROL', 'FUEL', 'PARKING',
    ],
    'Airtime & Data': ['AIRTIME', 'SAFARICOM DATA', 'BUNDLES'],
    'Bills & Utilities': [
      'KPLC', 'KENYA POWER', 'NAIROBI WATER', 'DSTV', 'GOTV', 'ZUKU',
      'JAMII TELECOM', 'STARTIMES',
    ],
    'Savings': ['M-SHWARI', 'MSHWARI', 'ZIIDI', 'KCB M-PESA', 'MALI', 'FULIZA'],
    'Health': ['HOSPITAL', 'CLINIC', 'PHARMACY', 'CHEMIST', 'NHIF', 'SHA'],
    'Education': ['SCHOOL', 'UNIVERSITY', 'COLLEGE', 'HELB', 'FEES'],
    'Loans & Credit': ['LOAN', 'CREDIT', 'BRANCH', 'TALA', 'ZENKA'],
  };

  /// Returns the best-guess category for a counterparty name, or
  /// Uncategorized if nothing matches.
  static String categorize(String? counterparty) {
    if (counterparty == null || counterparty.trim().isEmpty) {
      return Categories.uncategorized;
    }
    final upper = counterparty.toUpperCase();
    for (final entry in _keywordMap.entries) {
      for (final keyword in entry.value) {
        if (upper.contains(keyword)) return entry.key;
      }
    }
    return Categories.uncategorized;
  }
}