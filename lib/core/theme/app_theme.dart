import 'package:fluent_ui/fluent_ui.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryColor = Color(0xFF0078D4);
  static const Color accentColor = Color(0xFF0063B1);
  static const Color successColor = Color(0xFF107C10);
  static const Color warningColor = Color(0xFFFF8C00);
  static const Color errorColor = Color(0xFFD13438);
  static const Color infoColor = Color(0xFF0078D4);

  static FluentThemeData get lightTheme {
    return FluentThemeData(
      brightness: Brightness.light,
      accentColor: AccentColor.swatch({
        'darkest': const Color(0xFF004578),
        'darker': const Color(0xFF005A9E),
        'dark': const Color(0xFF106EBE),
        'normal': primaryColor,
        'light': const Color(0xFF2B88D8),
        'lighter': const Color(0xFF71AFE5),
        'lightest': const Color(0xFFC7E0F4),
      }),
      scaffoldBackgroundColor: const Color(0xFFF3F2F1),
      cardColor: Colors.white,
      typography: const Typography.raw(
        title: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Color(0xFF323130),
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFF323130),
        ),
        subtitle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF323130),
        ),
        body: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Color(0xFF323130),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Color(0xFF323130),
        ),
        bodyStrong: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF323130),
        ),
        caption: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: Color(0xFF605E5C),
        ),
      ),
    );
  }

  static FluentThemeData get darkTheme {
    return FluentThemeData(
      brightness: Brightness.dark,
      accentColor: AccentColor.swatch({
        'darkest': const Color(0xFF004578),
        'darker': const Color(0xFF005A9E),
        'dark': const Color(0xFF106EBE),
        'normal': primaryColor,
        'light': const Color(0xFF2B88D8),
        'lighter': const Color(0xFF71AFE5),
        'lightest': const Color(0xFFC7E0F4),
      }),
      scaffoldBackgroundColor: const Color(0xFF202020),
      cardColor: const Color(0xFF2D2D2D),
    );
  }
}

class AppStyles {
  AppStyles._();

  static const EdgeInsets screenPadding = EdgeInsets.all(24);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const double cardBorderRadius = 8;
  static const double buttonBorderRadius = 4;

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      );
}
