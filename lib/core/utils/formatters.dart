import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _currencyFormat = NumberFormat.currency(
    symbol: 'LKR ',
    decimalDigits: 2,
  );

  static final _numberFormat = NumberFormat('#,##0.00');
  static final _integerFormat = NumberFormat('#,##0');

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final _timeFormat = DateFormat('HH:mm');
  static final _isoDateFormat = DateFormat('yyyy-MM-dd');

  /// Formats a number as currency (LKR)
  static String currency(double? value) {
    if (value == null) return _currencyFormat.format(0);
    return _currencyFormat.format(value);
  }

  /// Formats a number with decimal places
  static String decimal(double? value) {
    if (value == null) return _numberFormat.format(0);
    return _numberFormat.format(value);
  }

  /// Formats an integer with thousand separators
  static String integer(int? value) {
    if (value == null) return _integerFormat.format(0);
    return _integerFormat.format(value);
  }

  /// Formats a percentage
  static String percentage(double? value, {int decimalPlaces = 1}) {
    if (value == null) return '0%';
    return '${value.toStringAsFixed(decimalPlaces)}%';
  }

  /// Formats a date for display
  static String date(DateTime? date) {
    if (date == null) return '-';
    return _dateFormat.format(date);
  }

  /// Formats a date and time for display
  static String dateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return _dateTimeFormat.format(dateTime);
  }

  /// Formats time only
  static String time(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return _timeFormat.format(dateTime);
  }

  /// Formats a date for storage/API
  static String isoDate(DateTime? date) {
    if (date == null) return '';
    return _isoDateFormat.format(date);
  }

  /// Formats a phone number
  static String phone(String? phone) {
    if (phone == null || phone.isEmpty) return '-';
    // Simple formatting - can be enhanced for specific formats
    return phone;
  }

  /// Truncates text with ellipsis
  static String truncate(String? text, int maxLength) {
    if (text == null) return '';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Formats duration in days
  static String daysAgo(DateTime? date) {
    if (date == null) return '-';
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '$diff days ago';
  }

  /// Formats file size
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
