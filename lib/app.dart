import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'presentation/providers/auth/auth_provider.dart';
import 'presentation/providers/core/theme_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/shell/navigation_shell.dart';

class CpPosApp extends ConsumerWidget {
  const CpPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final themeChoice = ref.watch(themeModeProvider);

    return FluentApp(
      title: 'CP POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: themeChoice == AppThemeChoice.clever
          ? AppTheme.cleverTheme
          : AppTheme.darkTheme,
      themeMode: themeChoice.mode,
      home: authState.isAuthenticated
          ? const NavigationShell()
          : const LoginScreen(),
    );
  }
}
