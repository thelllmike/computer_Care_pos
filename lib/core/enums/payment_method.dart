enum PaymentMethod {
  cash,
  card,
  bankTransfer,
  credit,
  cheque,
}

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.credit:
        return 'Credit';
      case PaymentMethod.cheque:
        return 'Cheque';
    }
  }

  String get code {
    switch (this) {
      case PaymentMethod.cash:
        return 'CASH';
      case PaymentMethod.card:
        return 'CARD';
      case PaymentMethod.bankTransfer:
        return 'BANK_TRANSFER';
      case PaymentMethod.credit:
        return 'CREDIT';
      case PaymentMethod.cheque:
        return 'CHEQUE';
    }
  }

  static PaymentMethod fromString(String value) {
    switch (value.toUpperCase()) {
      case 'CASH':
        return PaymentMethod.cash;
      case 'CARD':
        return PaymentMethod.card;
      case 'BANK_TRANSFER':
        return PaymentMethod.bankTransfer;
      case 'CREDIT':
        return PaymentMethod.credit;
      case 'CHEQUE':
        return PaymentMethod.cheque;
      default:
        return PaymentMethod.cash;
    }
  }
}
