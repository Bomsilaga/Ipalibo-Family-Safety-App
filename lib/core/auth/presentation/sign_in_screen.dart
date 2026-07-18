import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../auth_providers.dart';

/// Auth screen: ivory background, emerald headline, pill inputs, gold
/// primary button, outlined social sign-in (docs/04-design-system.md).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_isSignUp) {
        final response = await repo.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        // Supabase only returns an active session immediately when email
        // confirmation is disabled on the project. Otherwise there is no
        // signed-in user yet — proceeding to family setup here would hit
        // "requires a signed-in user", so wait for the confirmation click.
        if (response.session == null) {
          setState(() {
            _infoMessage =
                'Check your email to confirm your account, then sign in below.';
            _isSignUp = false;
          });
        } else if (mounted) {
          context.go('/family-setup');
        }
      } else {
        await repo.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) context.go('/home');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _oAuthSignIn({required bool isApple}) async {
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      if (isApple) {
        await repo.signInWithApple();
      } else {
        await repo.signInWithGoogle();
      }
    } catch (e) {
      final providerName = isApple ? 'Apple' : 'Google';
      final isNotEnabled = e.toString().contains('provider is not enabled');
      setState(() {
        _errorMessage = isNotEnabled
            ? '$providerName sign-in isn\'t set up yet — use email instead.'
            : 'Could not sign in with $providerName: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: colors.ivory,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  _isSignUp ? 'Create your account' : 'Welcome back',
                  style: typography.title.copyWith(color: colors.emerald900),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _isSignUp
                      ? 'Set up your family\'s command centre.'
                      : 'Sign in to The Ipalibos.',
                  style: typography.body.copyWith(color: colors.gray[6]),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Email'),
                  validator: (value) =>
                      (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Password'),
                  validator: (value) =>
                      (value == null || value.length < 8) ? 'At least 8 characters' : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_errorMessage!, style: typography.small.copyWith(color: colors.danger)),
                ],
                if (_infoMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_infoMessage!, style: typography.small.copyWith(color: colors.emerald700)),
                ],
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isSignUp ? 'Get Started' : 'Sign In'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _isSignUp = !_isSignUp;
                            _errorMessage = null;
                            _infoMessage = null;
                          }),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign in'
                        : 'New family? Create an account',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(children: [
                  Expanded(child: Divider(color: colors.gray[3])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text('or', style: typography.small.copyWith(color: colors.gray[5])),
                  ),
                  Expanded(child: Divider(color: colors.gray[3])),
                ]),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : () => _oAuthSignIn(isApple: true),
                  icon: const Icon(Icons.apple),
                  label: const Text('Continue with Apple'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : () => _oAuthSignIn(isApple: false),
                  icon: const Icon(Icons.g_mobiledata),
                  label: const Text('Continue with Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
