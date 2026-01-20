import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'presentation/providers/auth/auth_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/shell/navigation_shell.dart';

class LaptopShopPosApp extends ConsumerWidget {
  const LaptopShopPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return FluentApp(
      title: 'Laptop Shop POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: authState.isAuthenticated
          ? const NavigationShell()
          : const LoginScreen(),
    );
  }
}
