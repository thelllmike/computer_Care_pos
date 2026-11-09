import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart';
import 'database_provider.dart';
import 'settings_provider.dart';

const _themeModeKey = 'theme_mode';

/// App theme mode (light / dark / system), saved in local app settings.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final AppDatabase _db;
  final Ref _ref;

  ThemeModeNotifier(this._db, this._ref) : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await (_db.select(_db.appSettings)
            ..where((t) => t.key.equals(_themeModeKey)))
          .getSingleOrNull();
      state = _fromString(row?.value);
    } catch (_) {
      // Keep default light theme if settings can't be read.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _ref
        .read(settingsNotifierProvider.notifier)
        .saveSetting(_themeModeKey, mode.name);
  }

  static ThemeMode _fromString(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final db = ref.watch(databaseProvider);
  return ThemeModeNotifier(db, ref);
});
