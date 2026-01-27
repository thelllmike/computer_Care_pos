import 'package:drift/drift.dart';
import 'serial_numbers_table.dart';
import 'suppliers_table.dart';

class WarrantyClaims extends Table {
  TextColumn get id => text()();
  TextColumn get claimNumber => text().unique()(); // WC-2024-0001
  TextColumn get serialNumberId => text().references(SerialNumbers, #id)();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get claimReason => text()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))(); // PENDING, SENT_TO_SUPPLIER, IN_REPAIR, RETURNED, RESOLVED, REJECTED
  DateTimeColumn get dateSentToSupplier => dateTime().nullable()();
  DateTimeColumn get expectedReturnDate => dateTime().nullable()();
  DateTimeColumn get actualReturnDate => dateTime().nullable()();
  TextColumn get supplierResponse => text().nullable()();
  TextColumn get resolutionNotes => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class WarrantyClaimHistory extends Table {
  TextColumn get id => text()();
  TextColumn get warrantyClaimId => text().references(WarrantyClaims, #id)();
  TextColumn get fromStatus => text().nullable()();
  TextColumn get toStatus => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get changedBy => text().nullable()();
  DateTimeColumn get changedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Warranty claim status enum for type safety
enum WarrantyClaimStatus {
  pending('PENDING', 'Pending'),
  sentToSupplier('SENT_TO_SUPPLIER', 'Sent to Supplier'),
  inRepair('IN_REPAIR', 'In Repair'),
  returned('RETURNED', 'Returned'),
  resolved('RESOLVED', 'Resolved'),
  rejected('REJECTED', 'Rejected');

  final String code;
  final String displayName;

  const WarrantyClaimStatus(this.code, this.displayName);

  static WarrantyClaimStatus fromCode(String code) {
    return WarrantyClaimStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => WarrantyClaimStatus.pending,
    );
  }

  // Business logic: validate status transitions
  bool canTransitionTo(WarrantyClaimStatus newStatus) {
    switch (this) {
      case WarrantyClaimStatus.pending:
        return [
          WarrantyClaimStatus.sentToSupplier,
          WarrantyClaimStatus.rejected,
        ].contains(newStatus);
      case WarrantyClaimStatus.sentToSupplier:
        return [
          WarrantyClaimStatus.inRepair,
          WarrantyClaimStatus.returned,
          WarrantyClaimStatus.rejected,
        ].contains(newStatus);
      case WarrantyClaimStatus.inRepair:
        return [
          WarrantyClaimStatus.returned,
          WarrantyClaimStatus.rejected,
        ].contains(newStatus);
      case WarrantyClaimStatus.returned:
        return [
          WarrantyClaimStatus.resolved,
          WarrantyClaimStatus.rejected,
        ].contains(newStatus);
      case WarrantyClaimStatus.resolved:
      case WarrantyClaimStatus.rejected:
        return false; // Terminal states
    }
  }
}
