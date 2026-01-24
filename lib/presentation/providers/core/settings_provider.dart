import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database/app_database.dart';
import 'database_provider.dart';

const _uuid = Uuid();

// Settings keys
class SettingsKeys {
  static const companyName = 'company_name';
  static const companyAddress = 'company_address';
  static const companyPhone = 'company_phone';
  static const companyEmail = 'company_email';
  static const companyTaxId = 'company_tax_id';
  static const companyLogo = 'company_logo';
  static const receiptFooter = 'receipt_footer';
  static const thermalPrinterName = 'thermal_printer_name';
  static const a4PrinterName = 'a4_printer_name';
  static const defaultTaxRate = 'default_tax_rate';
  static const currencySymbol = 'currency_symbol';
}

// Company settings model
class CompanySettings {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String? taxId;
  final String? logoPath;
  final String? receiptFooter;

  CompanySettings({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.taxId,
    this.logoPath,
    this.receiptFooter,
  });

  CompanySettings copyWith({
    String? name,
    String? address,
    String? phone,
    String? email,
    String? taxId,
    String? logoPath,
    String? receiptFooter,
  }) {
    return CompanySettings(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      taxId: taxId ?? this.taxId,
      logoPath: logoPath ?? this.logoPath,
      receiptFooter: receiptFooter ?? this.receiptFooter,
    );
  }
}

// Provider to get a single setting
final settingProvider = FutureProvider.family<String?, String>((ref, key) async {
  final db = ref.watch(databaseProvider);
  final setting = await (db.select(db.appSettings)
        ..where((t) => t.key.equals(key)))
      .getSingleOrNull();
  return setting?.value;
});

// Provider for company settings
final companySettingsProvider = FutureProvider<CompanySettings>((ref) async {
  final db = ref.watch(databaseProvider);
  final settings = await db.select(db.appSettings).get();

  String getValue(String key) {
    final setting = settings.where((s) => s.key == key).firstOrNull;
    return setting?.value ?? '';
  }

  return CompanySettings(
    name: getValue(SettingsKeys.companyName),
    address: getValue(SettingsKeys.companyAddress),
    phone: getValue(SettingsKeys.companyPhone),
    email: getValue(SettingsKeys.companyEmail),
    taxId: getValue(SettingsKeys.companyTaxId).isEmpty ? null : getValue(SettingsKeys.companyTaxId),
    logoPath: getValue(SettingsKeys.companyLogo).isEmpty ? null : getValue(SettingsKeys.companyLogo),
    receiptFooter: getValue(SettingsKeys.receiptFooter).isEmpty ? null : getValue(SettingsKeys.receiptFooter),
  );
});

// Notifier to manage settings
class SettingsNotifier extends StateNotifier<AsyncValue<CompanySettings>> {
  final AppDatabase _db;
  final Ref _ref;

  SettingsNotifier(this._db, this._ref) : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _db.select(_db.appSettings).get();

      String getValue(String key) {
        final setting = settings.where((s) => s.key == key).firstOrNull;
        return setting?.value ?? '';
      }

      state = AsyncValue.data(CompanySettings(
        name: getValue(SettingsKeys.companyName),
        address: getValue(SettingsKeys.companyAddress),
        phone: getValue(SettingsKeys.companyPhone),
        email: getValue(SettingsKeys.companyEmail),
        taxId: getValue(SettingsKeys.companyTaxId).isEmpty ? null : getValue(SettingsKeys.companyTaxId),
        logoPath: getValue(SettingsKeys.companyLogo).isEmpty ? null : getValue(SettingsKeys.companyLogo),
        receiptFooter: getValue(SettingsKeys.receiptFooter).isEmpty ? null : getValue(SettingsKeys.receiptFooter),
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    final existing = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.appSettings)..where((t) => t.key.equals(key))).write(
        AppSettingsCompanion(
          value: Value(value),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      await _db.into(_db.appSettings).insert(
        AppSettingsCompanion.insert(
          id: _uuid.v4(),
          key: key,
          value: value,
        ),
      );
    }
  }

  Future<bool> saveCompanySettings(CompanySettings settings) async {
    try {
      await _saveSetting(SettingsKeys.companyName, settings.name);
      await _saveSetting(SettingsKeys.companyAddress, settings.address);
      await _saveSetting(SettingsKeys.companyPhone, settings.phone);
      await _saveSetting(SettingsKeys.companyEmail, settings.email);
      await _saveSetting(SettingsKeys.companyTaxId, settings.taxId ?? '');
      await _saveSetting(SettingsKeys.companyLogo, settings.logoPath ?? '');
      await _saveSetting(SettingsKeys.receiptFooter, settings.receiptFooter ?? '');

      state = AsyncValue.data(settings);
      _ref.invalidate(companySettingsProvider);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> saveSetting(String key, String value) async {
    try {
      await _saveSetting(key, value);
      _ref.invalidate(settingProvider(key));
      return true;
    } catch (e) {
      return false;
    }
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<CompanySettings>>((ref) {
  final db = ref.watch(databaseProvider);
  return SettingsNotifier(db, ref);
});
