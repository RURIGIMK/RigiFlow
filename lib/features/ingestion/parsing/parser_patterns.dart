class ParserPatterns {
  // Broadened to catch variants like M-PESA, MPESA, M-Pesa
  static const List<String> knownSenders = [
    'MPESA',
    'M-PESA',
    'EQUITY',
    'KCB',
    'COOP',
    'ABSA',
    'NCBA',
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