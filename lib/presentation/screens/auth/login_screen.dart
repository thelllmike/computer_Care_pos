import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/auth/auth_provider.dart';
import '../../widgets/clever_logo_animated.dart' show CleverLogoAnimated, CleverColors;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _showForm = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    await ref.read(authNotifierProvider.notifier).signIn(email, password);
  }

  void _showError(String message) {
    displayInfoBar(
      context,
      builder: (context, close) {
        return InfoBar(
          title: const Text('Error'),
          content: Text(message),
          severity: InfoBarSeverity.error,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.error != null) {
        _showError(next.error!);
        ref.read(authNotifierProvider.notifier).clearError();
      }
    });

    return FluentTheme(
      data: _loginTheme,
      child: Container(
        color: CleverColors.background,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CleverLogoAnimated(
                    size: 88,
                    onIntroDone: () {
                      if (mounted) setState(() => _showForm = true);
                    },
                  ),
                  const SizedBox(height: 48),
                  AnimatedOpacity(
                    opacity: _showForm ? 1 : 0,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOut,
                    child: AnimatedSlide(
                      offset: _showForm ? Offset.zero : const Offset(0, 0.06),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      child: IgnorePointer(
                        ignoring: !_showForm,
                        child: _buildForm(authState),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static final _loginTheme = FluentThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: CleverColors.background,
    accentColor: AccentColor.swatch(const {
      'darkest': Color(0xFF4C1D9E),
      'darker': Color(0xFF5B24BC),
      'dark': Color(0xFF6A2DD6),
      'normal': CleverColors.purple,
      'light': Color(0xFF9461F5),
      'lighter': Color(0xFFA67BF7),
      'lightest': CleverColors.lilac,
    }),
  );

  static const _muted = Color(0xFFB9B3CC);

  Widget _buildForm(AuthState authState) {
    final busy = authState.isLoading;
    Widget icon(IconData i) => Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Icon(i, size: 16, color: _muted),
        );
    final boxDecoration = BoxDecoration(
      color: CleverColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF2A2340)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Sign in to your POS',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        TextBox(
          controller: _emailController,
          placeholder: 'Email',
          keyboardType: TextInputType.emailAddress,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: boxDecoration,
          prefix: icon(FluentIcons.mail),
          enabled: !busy,
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 14),
        TextBox(
          controller: _passwordController,
          placeholder: 'Password',
          obscureText: !_showPassword,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: boxDecoration,
          prefix: icon(FluentIcons.lock),
          suffix: IconButton(
            icon: Icon(_showPassword ? FluentIcons.hide3 : FluentIcons.view, size: 16, color: _muted),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
          enabled: !busy,
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: busy ? null : _handleLogin,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.disabled)
                      ? CleverColors.purple.withValues(alpha: 0.5)
                      : states.contains(WidgetState.hovered)
                          ? const Color(0xFF8B50F0)
                          : CleverColors.purple),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: ProgressRing(strokeWidth: 2.5, activeColor: CleverColors.lime),
                  )
                : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Powered by Clever Project  ·  v${AppConstants.appVersion}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            color: Color(0xFF6E6880),
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
