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
      typography: const Typography.raw(
        title: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Color(0xFFF3F2F1)),
        titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFFF3F2F1)),
        subtitle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFFF3F2F1)),
        body: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFF3F2F1)),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Color(0xFFF3F2F1)),
        bodyStrong: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFF3F2F1)),
        caption: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFFC8C6C4)),
      ),
    );
  }

  // ---------------- Clever Project theme ----------------
  // Brand colours: ink background, purple accent, lilac and lime highlights.
  static const Color cleverPurple = Color(0xFF7B3AED);
  static const Color cleverPurpleDark = Color(0xFF6A2DD6);
  static const Color cleverLilac = Color(0xFFB794FF);
  static const Color cleverLime = Color(0xFFD5FD44);
  static const Color cleverInk = Color(0xFF120E22); // page background
  static const Color cleverSurface = Color(0xFF1B1630); // cards, panels
  static const Color cleverSubtle = Color(0xFF241D3D); // headers, hover fills
  static const Color cleverDivider = Color(0xFF2F2752);
  static const Color cleverText = Color(0xFFF3F0FF);
  static const Color cleverMuted = Color(0xFFB9B3CC);

  static FluentThemeData get cleverTheme {
    const mono = 'JetBrainsMono';
    return FluentThemeData(
      brightness: Brightness.dark,
      // Selection colour = Clever lime: selected menu item, checked radio /
      // checkbox / toggle, focused text box, progress rings. Buttons and
      // icons stay purple (see buttonTheme and AppTheme.primary).
      accentColor: AccentColor.swatch(const {
        'darkest': Color(0xFF5C7A00),
        'darker': Color(0xFF7AA300),
        'dark': Color(0xFFA6CF1F),
        'normal': cleverLime,
        'light': Color(0xFFDEFF6E),
        'lighter': Color(0xFFE6FF8F),
        'lightest': Color(0xFFF0FFC2),
      }),
      scaffoldBackgroundColor: cleverInk,
      micaBackgroundColor: cleverInk,
      acrylicBackgroundColor: cleverInk,
      cardColor: cleverSurface,
      menuColor: cleverSurface,
      inactiveBackgroundColor: cleverSubtle,
      // Brand buttons: solid purple with white text (Fluent's dark default
      // would use a pale lilac with dark text).
      buttonTheme: ButtonThemeData(
        filledButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return cleverPurple.withValues(alpha: 0.4);
            if (states.contains(WidgetState.pressed)) return cleverPurpleDark;
            if (states.contains(WidgetState.hovered)) return const Color(0xFF8B50F0);
            return cleverPurple;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.disabled) ? Colors.white.withValues(alpha: 0.6) : Colors.white),
        ),
      ),
      resources: const ResourceDictionary.dark(
        solidBackgroundFillColorBase: cleverInk,
        solidBackgroundFillColorSecondary: cleverSurface,
        solidBackgroundFillColorTertiary: cleverSubtle,
        cardBackgroundFillColorDefault: Color(0x0DB794FF),
        cardStrokeColorDefault: cleverDivider,
        dividerStrokeColorDefault: cleverDivider,
        layerFillColorDefault: Color(0x4D1B1630),
        subtleFillColorSecondary: Color(0x14B794FF),
        subtleFillColorTertiary: Color(0x0FB794FF),
        textFillColorPrimary: cleverText,
        textFillColorSecondary: cleverMuted,
      ),
      typography: const Typography.raw(
        title: TextStyle(fontFamily: mono, fontSize: 26, fontWeight: FontWeight.w800, color: cleverText),
        titleLarge: TextStyle(fontFamily: mono, fontSize: 24, fontWeight: FontWeight.w800, color: cleverText),
        subtitle: TextStyle(fontFamily: mono, fontSize: 19, fontWeight: FontWeight.w700, color: cleverText),
        body: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: cleverText),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: cleverText),
        bodyStrong: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cleverText),
        caption: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: cleverMuted),
      ),
    );
  }

  static bool isDark(BuildContext context) =>
      FluentTheme.of(context).brightness == Brightness.dark;

  /// True when the Clever Project theme is active.
  static bool isClever(BuildContext context) =>
      FluentTheme.of(context).scaffoldBackgroundColor == cleverInk;

  /// Main brand colour for icons, highlights and badges (follows the theme).
  static Color primary(BuildContext context) =>
      isClever(context) ? cleverPurple : primaryColor;

  /// Secondary brand colour (follows the theme).
  static Color accent(BuildContext context) =>
      isClever(context) ? cleverPurpleDark : accentColor;

  /// Border / divider color that works in every theme.
  static Color dividerColor(BuildContext context) => isClever(context)
      ? cleverDivider
      : isDark(context)
          ? const Color(0xFF3B3A39)
          : Colors.grey[40];

  /// Subtle header/background fill that works in every theme.
  static Color subtleFill(BuildContext context) => isClever(context)
      ? cleverSubtle
      : isDark(context)
          ? const Color(0xFF323130)
          : Colors.grey[20];

  /// Panel/surface color (cards, footers).
  static Color surfaceColor(BuildContext context) => isClever(context)
      ? cleverSurface
      : isDark(context)
          ? const Color(0xFF2D2D2D)
          : Colors.white;
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
