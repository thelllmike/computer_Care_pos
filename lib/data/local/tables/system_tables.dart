import 'package:drift/drift.dart';

class AuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get auditTableName => text()();
  TextColumn get recordId => text()();
  TextColumn get action => text()(); // INSERT, UPDATE, DELETE
  TextColumn get oldData => text().nullable()(); // JSON
  TextColumn get newData => text().nullable()(); // JSON
  TextColumn get changedBy => text().nullable()();
  DateTimeColumn get changedAt => dateTime().withDefault(currentDateAndTime)();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class NumberSequences extends Table {
  TextColumn get id => text()();
  TextColumn get sequenceType => text().unique()(); // INVOICE, QUOTATION, PO, GRN, REPAIR_JOB, CUSTOMER, SUPPLIER, PRODUCT
  TextColumn get prefix => text()();
  IntColumn get currentYear => integer()();
  IntColumn get lastNumber => integer().withDefault(const Constant(0))();
  TextColumn get format => text().withDefault(const Constant('{PREFIX}-{YEAR}-{NUMBER:4}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  // Sync columns
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncMetadata extends Table {
  TextColumn get id => text()();
  TextColumn get syncTableName => text().unique()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  IntColumn get pendingCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get queueTableName => text()();
  TextColumn get recordId => text()();
  TextColumn get operation => text()(); // INSERT, UPDATE, DELETE
  TextColumn get payload => text()(); // JSON
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get processedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettings extends Table {
  TextColumn get id => text()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
  TextColumn get dataType => text().withDefault(const Constant('STRING'))(); // STRING, INT, DOUBLE, BOOL, JSON
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
