import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/local/database/app_database.dart';

/// Result of an import.
class ImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;
  const ImportResult(this.imported, this.skipped, this.errors);
}

/// Full data backup (export) and restore (import) for the local database.
///
/// Export writes every business table as JSON. Import merges rows by `id`:
/// existing records with the same id are updated, new ones are added, and
/// nothing is deleted. Imported rows are marked PENDING so the next sync
/// uploads them to Supabase.
class BackupService {
  static const formatName = 'cp_pos_backup';
  static const formatVersion = 1;

  /// Internal sync bookkeeping is machine-specific, so it is never exported.
  static const _excludedTables = {'sync_queue', 'sync_metadata'};

  final AppDatabase _db;
  BackupService(this._db);

  List<String> get _tableNames => _db.allTables
      .map((t) => t.actualTableName)
      .where((n) => !_excludedTables.contains(n))
      .toList();

  /// Builds the backup as a JSON string.
  Future<String> exportToJson() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final name in _tableNames) {
      final rows = await _db.customSelect('SELECT * FROM "$name"').get();
      tables[name] = rows.map((r) => r.data).toList();
    }
    return const JsonEncoder.withIndent(' ').convert({
      'format': formatName,
      'formatVersion': formatVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
    });
  }

  /// Counts rows per table in a backup file, for the confirm dialog.
  /// Throws [FormatException] if the file isn't a CP POS backup.
  Map<String, int> summarize(String json) {
    final tables = _parse(json);
    return {
      for (final e in tables.entries) e.key: (e.value as List).length,
    };
  }

  /// Merges a backup into the local database.
  Future<ImportResult> importFromJson(String json) async {
    final tables = _parse(json);
    var imported = 0;
    var skipped = 0;
    final errors = <String>[];

    await _db.transaction(() async {
      for (final name in _tableNames) {
        final rows = tables[name];
        if (rows is! List || rows.isEmpty) continue;

        // Only use columns that exist in this version of the app.
        final info = await _db.customSelect('PRAGMA table_info("$name")').get();
        final columns = info.map((r) => r.read<String>('name')).toSet();
        final hasSyncStatus = columns.contains('sync_status');

        for (final raw in rows) {
          if (raw is! Map) continue;
          final row = Map<String, Object?>.from(raw)
            ..removeWhere((k, _) => !columns.contains(k));
          if (!row.containsKey('id')) {
            skipped++;
            continue;
          }
          if (hasSyncStatus) row['sync_status'] = 'PENDING';

          final cols = row.keys.toList();
          final colList = cols.map((c) => '"$c"').join(', ');
          final placeholders = List.filled(cols.length, '?').join(', ');
          final updates = cols
              .where((c) => c != 'id')
              .map((c) => '"$c" = excluded."$c"')
              .join(', ');

          try {
            await _db.customStatement(
              'INSERT INTO "$name" ($colList) VALUES ($placeholders) '
              'ON CONFLICT(id) DO ${updates.isEmpty ? 'NOTHING' : 'UPDATE SET $updates'}',
              cols.map((c) => row[c]).toList(),
            );
            imported++;
          } catch (e) {
            // Usually a clash on a unique number/code held by a different record.
            skipped++;
            if (errors.length < 20) errors.add('$name/${row['id']}: $e');
          }
        }
      }
    });

    // Refresh every stream/query watching the database.
    _db.notifyUpdates({
      for (final t in _db.allTables) TableUpdate.onTable(t),
    });

    return ImportResult(imported, skipped, errors);
  }

  Map<String, dynamic> _parse(String json) {
    final dynamic data;
    try {
      data = jsonDecode(json);
    } catch (_) {
      throw const FormatException('This file is not a valid backup (bad JSON).');
    }
    if (data is! Map || data['format'] != formatName || data['tables'] is! Map) {
      throw const FormatException('This file is not a CP POS backup.');
    }
    return Map<String, dynamic>.from(data['tables'] as Map);
  }
}
