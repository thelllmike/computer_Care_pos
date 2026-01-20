enum OrderStatus {
  draft,
  confirmed,
  partiallyReceived,
  completed,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.draft:
        return 'Draft';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.partiallyReceived:
        return 'Partially Received';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get code {
    switch (this) {
      case OrderStatus.draft:
        return 'DRAFT';
      case OrderStatus.confirmed:
        return 'CONFIRMED';
      case OrderStatus.partiallyReceived:
        return 'PARTIALLY_RECEIVED';
      case OrderStatus.completed:
        return 'COMPLETED';
      case OrderStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static OrderStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'DRAFT':
        return OrderStatus.draft;
      case 'CONFIRMED':
        return OrderStatus.confirmed;
      case 'PARTIALLY_RECEIVED':
        return OrderStatus.partiallyReceived;
      case 'COMPLETED':
        return OrderStatus.completed;
      case 'CANCELLED':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.draft;
    }
  }
}

enum QuotationStatus {
  draft,
  sent,
  accepted,
  rejected,
  expired,
  converted,
}

extension QuotationStatusExtension on QuotationStatus {
  String get displayName {
    switch (this) {
      case QuotationStatus.draft:
        return 'Draft';
      case QuotationStatus.sent:
        return 'Sent';
      case QuotationStatus.accepted:
        return 'Accepted';
      case QuotationStatus.rejected:
        return 'Rejected';
      case QuotationStatus.expired:
        return 'Expired';
      case QuotationStatus.converted:
        return 'Converted to Invoice';
    }
  }

  String get code {
    switch (this) {
      case QuotationStatus.draft:
        return 'DRAFT';
      case QuotationStatus.sent:
        return 'SENT';
      case QuotationStatus.accepted:
        return 'ACCEPTED';
      case QuotationStatus.rejected:
        return 'REJECTED';
      case QuotationStatus.expired:
        return 'EXPIRED';
      case QuotationStatus.converted:
        return 'CONVERTED';
    }
  }

  static QuotationStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'DRAFT':
        return QuotationStatus.draft;
      case 'SENT':
        return QuotationStatus.sent;
      case 'ACCEPTED':
        return QuotationStatus.accepted;
      case 'REJECTED':
        return QuotationStatus.rejected;
      case 'EXPIRED':
        return QuotationStatus.expired;
      case 'CONVERTED':
        return QuotationStatus.converted;
      default:
        return QuotationStatus.draft;
    }
  }
}
