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
    final providerName = isApple ? 'Apple' : 'Google';
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });

    // Guard *before* calling signInWithOAuth, not after. On web that call
    // is a full top-level browser redirect to Supabase, which happens
    // before any Dart runs — if the provider is switched off the user
    // just lands on Supabase's raw JSON error page and there is no
    // exception to catch. Checking /auth/v1/settings first is the only
    // way to fail politely.
    final providers = await ref.read(enabledOAuthProvidersProvider.future);
    if (!providers.contains(isApple ? 'apple' : 'google')) {
      setState(() {
        _errorMessage = '$providerName sign-in isn\'t switched on for this app yet. '
            'Enable the $providerName provider in Supabase → Authentication → Providers, '
            'then it\'ll work here. Use email for now.';
      });
      return;
    }

    try {
      final repo = ref.read(authRepositoryProvider);
      if (isApple) {
        await repo.signInWithApple();
      } else {
        await repo.signInWithGoogle();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not sign in with $providerName: $e');
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
                // Both social buttons are always shown, per the brand
                // mockup. Whether a provider is actually enabled is
                // handled in _oAuthSignIn, which checks before redirecting
                // and explains what to switch on rather than dumping the
                // user on Supabase's raw error page.
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
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    side: BorderSide(color: colors.gray[3]),
                    foregroundColor: colors.gray[9],
                  ),
                  onPressed: _isSubmitting ? null : () => _oAuthSignIn(isApple: true),
                  icon: const Icon(Icons.apple, size: 22),
                  label: const Text('Continue with Apple'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    side: BorderSide(color: colors.gray[3]),
                    foregroundColor: colors.gray[9],
                  ),
                  onPressed: _isSubmitting ? null : () => _oAuthSignIn(isApple: false),
                  icon: const _GoogleGlyph(size: 20),
                  label: const Text('Continue with Google'),
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

/// Google's "G" in its four brand colours. Drawn rather than shipped as an
/// asset so it needs no network fetch (the app's CSP blocks remote images)
/// and stays sharp at any size. Material's `Icons.g_mobiledata` is a
/// single-colour glyph that reads as a generic letter, not as Google.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four quadrant arcs, starting at the right and going clockwise, in
    // Google's canonical colour order.
    void arc(double startDeg, double sweepDeg, Color color) {
      paint.color = color;
      canvas.drawArc(rect, startDeg * 3.1415926535 / 180, sweepDeg * 3.1415926535 / 180, false, paint);
    }

    arc(-40, 75, _blue); // right side, where the crossbar meets
    arc(35, 90, _green);
    arc(125, 100, _yellow);
    arc(225, 95, _red);

    // The horizontal crossbar of the G.
    final bar = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.52, size.height * 0.40, size.width * 0.46, stroke),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
