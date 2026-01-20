import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.accentColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Card(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo and title
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        FluentIcons.laptop_secure,
                        size: 48,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppConstants.appName,
                      style: FluentTheme.of(context).typography.title?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to continue',
                      style: FluentTheme.of(context).typography.body?.copyWith(
                            color: Colors.grey[100],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Email field
                InfoLabel(
                  label: 'Email',
                  child: TextBox(
                    controller: _emailController,
                    placeholder: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.mail, size: 16),
                    ),
                    enabled: !authState.isLoading,
                    onSubmitted: (_) => _handleLogin(),
                  ),
                ),
                const SizedBox(height: 16),
                // Password field
                InfoLabel(
                  label: 'Password',
                  child: TextBox(
                    controller: _passwordController,
                    placeholder: 'Enter your password',
                    obscureText: !_showPassword,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.lock, size: 16),
                    ),
                    suffix: IconButton(
                      icon: Icon(
                        _showPassword ? FluentIcons.hide3 : FluentIcons.view,
                        size: 16,
                      ),
                      onPressed: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                    ),
                    enabled: !authState.isLoading,
                    onSubmitted: (_) => _handleLogin(),
                  ),
                ),
                const SizedBox(height: 24),
                // Login button
                FilledButton(
                  onPressed: authState.isLoading ? null : _handleLogin,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 16),
                // Version info
                Center(
                  child: Text(
                    'Version ${AppConstants.appVersion}',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: Colors.grey[100],
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
