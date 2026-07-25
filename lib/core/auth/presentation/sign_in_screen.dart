import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/settings/data/pending_invite.dart';
import '../../network/auth_settings.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../auth_providers.dart';
import 'brand_crest.dart';

/// Auth screen, laid out to the brand mockup: crest + wordmark header,
/// "Welcome Back", pill inputs, emerald primary button, "or continue
/// with" divider and outlined social buttons.
///
/// Opens in sign-up mode when reached as `/sign-in?mode=signup` (the
/// welcome screen's "Get Started"), sign-in mode otherwise.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.startInSignUp = false});

  final bool startInSignUp;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late bool _isSignUp = widget.startInSignUp;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
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

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Enter your email above first, then tap "Forgot password?"');
      return;
    }
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      setState(() => _infoMessage = 'Password reset email sent — check your inbox.');
    } catch (e) {
      setState(() => _errorMessage = 'Could not send reset email: $e');
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
    final pendingInvite = ref.watch(pendingInviteCodeProvider).value;
    return Scaffold(
      backgroundColor: colors.ivory,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: colors.emerald900),
                      onPressed: () => context.go('/welcome'),
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        BrandCrest(size: 30),
                        const SizedBox(height: 4),
                        const BrandWordmark(fontSize: 11),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // An invitee who followed a link arrives here needing to
                // make an account first — say why, so the detour makes
                // sense and they don't drop out.
                if (pendingInvite != null && pendingInvite.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: colors.emerald700.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.family_restroom_outlined, color: colors.emerald700),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'You\'ve been invited to a family. Create an account (or sign in) and we\'ll add you automatically.',
                            style: typography.small.copyWith(color: colors.emerald900),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  _isSignUp ? 'Create your account' : 'Welcome Back',
                  textAlign: TextAlign.center,
                  style: typography.title.copyWith(color: colors.emerald900),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _isSignUp ? 'Set up your family\'s command centre.' : 'Sign in to continue',
                  textAlign: TextAlign.center,
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
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
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
                if (!_isSignUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.emerald900,
                    foregroundColor: colors.ivory,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isSignUp ? 'Get Started' : 'Sign In'),
                ),
                // On web, tapping a disabled OAuth provider does a full
                // top-level browser redirect straight to Supabase before
                // any Dart code runs, surfacing its raw JSON error page —
                // there's no exception to catch client-side. Only show a
                // provider's button once /auth/v1/settings confirms it's
                // actually turned on.
                Consumer(builder: (context, ref, _) {
                  final providersAsync = ref.watch(enabledOAuthProvidersProvider);
                  final providers = providersAsync.value ?? const {};
                  final showApple = providers.contains('apple');
                  final showGoogle = providers.contains('google');
                  if (!showApple && !showGoogle) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      Row(children: [
                        Expanded(child: Divider(color: colors.gray[3])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          child: Text('or continue with',
                              style: typography.small.copyWith(color: colors.gray[5])),
                        ),
                        Expanded(child: Divider(color: colors.gray[3])),
                      ]),
                      const SizedBox(height: AppSpacing.lg),
                      if (showApple)
                        OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : () => _oAuthSignIn(isApple: true),
                          icon: const Icon(Icons.apple),
                          label: const Text('Continue with Apple'),
                        ),
                      if (showApple && showGoogle) const SizedBox(height: AppSpacing.sm),
                      if (showGoogle)
                        OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : () => _oAuthSignIn(isApple: false),
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Continue with Google'),
                        ),
                    ],
                  );
                }),
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
                        : 'Don\'t have an account? Sign up',
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
