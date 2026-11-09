import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cp_pos/data/local/database/app_database.dart';
import 'package:cp_pos/services/backup/backup_service.dart';

void main() {
  test('export then import restores data and marks it pending', () async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    final created = DateTime(2026, 1, 2, 3, 4, 5);
    await source.into(source.categories).insert(CategoriesCompanion.insert(
          id: 'c1', code: 'LAP', name: 'Laptops', createdAt: Value(created)));
    await source.into(source.categories).insert(CategoriesCompanion.insert(
          id: 'c2', code: 'ACC', name: 'Accessories'));

    final json = await BackupService(source).exportToJson();
    expect(BackupService(source).summarize(json)['categories'], 2);

    final target = AppDatabase.forTesting(NativeDatabase.memory());
    // Existing record with same id gets overwritten; unrelated one is kept.
    await target.into(target.categories).insert(CategoriesCompanion.insert(
          id: 'c1', code: 'OLD', name: 'Old name'));
    await target.into(target.categories).insert(CategoriesCompanion.insert(
          id: 'c9', code: 'KEEP', name: 'Keep me'));

    final result = await BackupService(target).importFromJson(json);
    expect(result.imported, greaterThanOrEqualTo(2));
    expect(result.skipped, 0);

    final rows = await target.select(target.categories).get();
    final byId = {for (final r in rows) r.id: r};
    expect(byId.keys.toSet(), {'c1', 'c2', 'c9'});
    expect(byId['c1']!.name, 'Laptops');
    expect(byId['c1']!.createdAt, created);
    expect(byId['c1']!.syncStatus, 'PENDING');
    expect(byId['c9']!.name, 'Keep me');

    expect(() => BackupService(target).summarize('{"x":1}'),
        throwsA(isA<FormatException>()));
    await source.close();
    await target.close();
  });
}
