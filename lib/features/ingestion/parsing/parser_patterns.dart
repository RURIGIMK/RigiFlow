class ParserPatterns {
  static const List<String> knownSenders = [
    'MPESA',
    'M-PESA',
    'EQUITY',
    'KCB',
    'COOP',
    'CO-OP',
    'ABSA',
    'NCBA',
    'DTB',
    'FAMILY BANK',
    'STANBIC',
    'I&M',
    'STANCHART',
    'STANDARD CHARTERED',
    'GTBANK',
    'BANK',
  ];

  // ---------------- M-PESA ----------------
  static final RegExp mpesaSent = RegExp(
    r'([A-Z0-9]{10})\s+Confirmed\.\s*Ksh([\d,]+\.\d{2})\s+sent to\s+(.+?)\s+on',
    caseSensitive: false,
  );

  static final RegExp mpesaReceived = RegExp(
    r'([A-Z0-9]{10})\s+Confirmed\.\s*You have received\s+Ksh([\d,]+\.\d{2})\s+from\s+(.+?)\s+on',
    caseSensitive: false,
  );

  static final RegExp mpesaPaybill = RegExp(
    r'([A-Z0-9]{10})\s+Confirmed\.\s*Ksh([\d,]+\.\d{2})\s+paid to\s+(.+?)\s+for account',
    caseSensitive: false,
  );

  static final RegExp mpesaTill = RegExp(
    r'([A-Z0-9]{10})\s+Confirmed\.\s*Ksh([\d,]+\.\d{2})\s+paid to\s+(.+?)\s+on',
    caseSensitive: false,
  );

  static final RegExp mpesaWithdraw = RegExp(
    r'([A-Z0-9]{10})\s+Confirmed\.\s*Ksh([\d,]+\.\d{2})\s+withdrawn from\s+(.+?)\s+on',
    caseSensitive: false,
  );

  static final RegExp mpesaAirtime = RegExp(
    r'([A-Z0-9]{10})\s+Confirmed\.\s*You bought\s+Ksh([\d,]+\.\d{2})\s+of airtime',
    caseSensitive: false,
  );

  static final RegExp mpesaTransferToSavings = RegExp(
    r'([A-Z0-9]{10})\s+Confirmed\.\s*Ksh([\d,]+\.\d{2})\s+transferred to\s+(.+?)\s+account\s+on',
    caseSensitive: false,
  );

  static final RegExp mpesaTransferFromSavings = RegExp(
    r'([A-Z0-9]{10})\s+Confirmed\.\s*You have transferred\s+Ksh([\d,]+\.\d{2})\s+from your\s+(.+?)\s+account\s+on',
    caseSensitive: false,
  );

  // ---------------- BANKS ----------------
  static final RegExp bankDebit = RegExp(
    r'DEBITED\s+with\s+KES\s*([\d,]+\.\d{2})',
    caseSensitive: false,
  );

  static final RegExp bankCredit = RegExp(
    r'CREDITED\s+with\s+KES\s*([\d,]+\.\d{2})',
    caseSensitive: false,
  );
}