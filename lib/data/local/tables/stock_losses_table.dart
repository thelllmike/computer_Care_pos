import 'package:drift/drift.dart';
import 'products_table.dart';
import 'serial_numbers_table.dart';

class StockLosses extends Table {
  TextColumn get id => text()();
  TextColumn get lossNumber => text().unique()(); // LOSS-2024-0001
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get quantity => integer()();
  TextColumn get serialNumberId => text().nullable().references(SerialNumbers, #id)(); // For serialized items
  TextColumn get lossType => text()(); // DAMAGED, LOST, STOLEN, EXPIRED
  TextColumn get lossReason => text()();
  RealColumn get unitCost => real()();
  RealColumn get totalLossAmount => real()();
  DateTimeColumn get lossDate => dateTime()();
  TextColumn get notes => text().nullable()();
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

// Loss type enum for type safety
enum LossType {
  damaged('DAMAGED', 'Damaged'),
  lost('LOST', 'Lost'),
  stolen('STOLEN', 'Stolen'),
  expired('EXPIRED', 'Expired');

  final String code;
  final String displayName;

  const LossType(this.code, this.displayName);

  static LossType fromCode(String code) {
    return LossType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => LossType.damaged,
    );
  }
}
