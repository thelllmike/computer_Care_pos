import 'package:drift/drift.dart';
import 'customers_table.dart';

class RepairJobs extends Table {
  TextColumn get id => text()();
  TextColumn get jobNumber => text().unique()();
  TextColumn get customerId => text().nullable().references(Customers, #id)(); // Nullable for manual customers
  TextColumn get manualCustomerName => text().nullable()(); // For walk-in customers without database entry
  TextColumn get manualCustomerPhone => text().nullable()(); // Phone for manual customers
  TextColumn get serialNumberId => text().nullable()(); // If it's our sold device
  TextColumn get deviceType => text()(); // LAPTOP, PHONE, etc.
  TextColumn get deviceBrand => text().nullable()();
  TextColumn get deviceModel => text().nullable()();
  TextColumn get deviceSerial => text().nullable()(); // External serial for non-stock items
  TextColumn get problemDescription => text()();
  TextColumn get diagnosis => text().nullable()();
  RealColumn get estimatedCost => real().withDefault(const Constant(0.0))();
  RealColumn get actualCost => real().withDefault(const Constant(0.0))();
  RealColumn get laborCost => real().withDefault(const Constant(0.0))();
  RealColumn get partsCost => real().withDefault(const Constant(0.0))();
  RealColumn get totalCost => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('RECEIVED'))();
  BoolColumn get isUnderWarranty => boolean().withDefault(const Constant(false))();
  TextColumn get warrantyNotes => text().nullable()();
  DateTimeColumn get receivedDate => dateTime()();
  DateTimeColumn get promisedDate => dateTime().nullable()();
  DateTimeColumn get completedDate => dateTime().nullable()();
  DateTimeColumn get deliveredDate => dateTime().nullable()();
  TextColumn get receivedBy => text().nullable()();
  TextColumn get assignedTo => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get invoiceId => text().nullable()(); // Links to generated invoice to prevent duplicates
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class RepairParts extends Table {
  TextColumn get id => text()();
  TextColumn get repairJobId => text().references(RepairJobs, #id)();
  TextColumn get productId => text()();
  TextColumn get serialNumberId => text().nullable()(); // If serialized part
  IntColumn get quantity => integer()();
  RealColumn get unitCost => real()();
  RealColumn get unitPrice => real()();
  RealColumn get totalCost => real()();
  RealColumn get totalPrice => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class RepairStatusHistory extends Table {
  TextColumn get id => text()();
  TextColumn get repairJobId => text().references(RepairJobs, #id)();
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
