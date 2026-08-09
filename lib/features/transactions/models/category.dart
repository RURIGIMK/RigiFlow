class TransactionCategory {
  final String name;
  final String icon; // Material icon name, stored as string for simplicity
  const TransactionCategory(this.name, this.icon);
}

/// Starting taxonomy — editable later via category correction, which
/// teaches the merchant→category rules in category_rules.dart.
class Categories {
  static const List<TransactionCategory> all = [
    TransactionCategory('Food & Groceries', 'restaurant'),
    TransactionCategory('Transport', 'directions_car'),
    TransactionCategory('Airtime & Data', 'phone_android'),
    TransactionCategory('Bills & Utilities', 'receipt_long'),
    TransactionCategory('Rent', 'home'),
    TransactionCategory('Savings', 'savings'),
    TransactionCategory('Shopping', 'shopping_bag'),
    TransactionCategory('Health', 'local_hospital'),
    TransactionCategory('Entertainment', 'movie'),
    TransactionCategory('Education', 'school'),
    TransactionCategory('Family & Friends', 'people'),
    TransactionCategory('Salary & Income', 'payments'),
    TransactionCategory('Loans & Credit', 'account_balance'),
    TransactionCategory('Fees & Charges', 'toll'),
    TransactionCategory('Uncategorized', 'help_outline'),
  ];

  static const String uncategorized = 'Uncategorized';
  static const String savings = 'Savings';

  static List<String> get names => all.map((c) => c.name).toList();
}