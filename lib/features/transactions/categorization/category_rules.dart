import '../models/category.dart';

class CategoryRules {
  static const Map<String, List<String>> _keywordMap = {
    'Food & Groceries': [
      'NAIVAS', 'CARREFOUR', 'QUICKMART', 'CHANDARANA', 'TUSKYS', 'CLEANSHELF',
      'SUPERMARKET', 'BUTCHERY', 'RESTAURANT', 'CAFE', 'HOTEL', 'EATERY',
      'KFC', 'JAVA', 'PIZZA', 'FOOD', 'BAKERY', 'GROCER', 'MART', 'KITCHEN',
      'DOMINOS', 'BURGER', 'CHICKEN',
    ],
    'Transport': [
      'UBER', 'BOLT', 'LITTLE CAB', 'MATATU', 'SGR', 'SHELL', 'TOTAL',
      'RUBIS', 'PETROL', 'FUEL', 'PARKING', 'GARAGE', 'AUTO', 'SPARES',
      'OLA', 'FARE', 'TAXI',
    ],
    'Airtime & Data': ['AIRTIME', 'SAFARICOM DATA', 'BUNDLES', 'TOPUP', 'TOP UP'],
    'Bills & Utilities': [
      'KPLC', 'KENYA POWER', 'NAIROBI WATER', 'DSTV', 'GOTV', 'ZUKU',
      'JAMII TELECOM', 'STARTIMES', 'ELECTRICITY', 'WATER', 'WASREB',
      'INTERNET', 'WIFI', 'FIBER',
    ],
    'Savings': [
      'M-SHWARI', 'MSHWARI', 'ZIIDI', 'KCB M-PESA', 'MALI', 'FULIZA',
      'SACCO', 'MMF', 'MONEY MARKET',
    ],
    'Health': [
      'HOSPITAL', 'CLINIC', 'PHARMACY', 'CHEMIST', 'NHIF', 'SHA',
      'MEDICAL', 'DOCTOR', 'DENTAL', 'LAB',
    ],
    'Education': [
      'SCHOOL', 'UNIVERSITY', 'COLLEGE', 'HELB', 'FEES', 'ACADEMY',
      'TUITION', 'BOOKS',
    ],
    'Loans & Credit': [
      'LOAN', 'CREDIT', 'BRANCH', 'TALA', 'ZENKA', 'HUSTLER FUND',
      'MSHIKAMANO', 'OKASH', 'BRIDGE',
    ],
    'Shopping': [
      'JUMIA', 'KILIMALL', 'MASOKO', 'SHOP', 'STORE', 'BOUTIQUE',
      'FASHION', 'ELECTRONICS', 'HARDWARE',
    ],
    'Entertainment': [
      'CINEMA', 'MOVIE', 'NETFLIX', 'SHOWMAX', 'SPOTIFY', 'BETTING',
      'SPORTPESA', 'BETIKA', 'CLUB', 'BAR', 'LOUNGE',
    ],
    'Rent': ['RENT', 'LANDLORD', 'HOUSING', 'ESTATE'],
    'Fees & Charges': ['CHARGE', 'FEE', 'COMMISSION', 'TAX', 'KRA'],
  };

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