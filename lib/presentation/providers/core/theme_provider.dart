import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart';
import 'database_provider.dart';
import 'settings_provider.dart';

const _themeModeKey = 'theme_mode';

/// The themes a user can pick in Settings → Appearance.
enum AppThemeChoice {
  light,
  dark,
  system,
  clever;

  /// What FluentApp should use for light/dark switching.
  ThemeMode get mode => switch (this) {
        AppThemeChoice.light => ThemeMode.light,
        AppThemeChoice.dark => ThemeMode.dark,
        AppThemeChoice.system => ThemeMode.system,
        AppThemeChoice.clever => ThemeMode.dark,
      };
}

/// App theme (light / dark / system / Clever Project), saved in local app settings.
class ThemeModeNotifier extends StateNotifier<AppThemeChoice> {
  final AppDatabase _db;
  final Ref _ref;

  ThemeModeNotifier(this._db, this._ref) : super(AppThemeChoice.light) {
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

  Future<void> setTheme(AppThemeChoice choice) async {
    state = choice;
    await _ref
        .read(settingsNotifierProvider.notifier)
        .saveSetting(_themeModeKey, choice.name);
  }

  static AppThemeChoice _fromString(String? value) => AppThemeChoice.values
      .firstWhere((c) => c.name == value, orElse: () => AppThemeChoice.light);
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeChoice>((ref) {
  final db = ref.watch(databaseProvider);
  return ThemeModeNotifier(db, ref);
});
