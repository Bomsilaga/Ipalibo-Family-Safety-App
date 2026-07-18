import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../app_lock_service.dart';

/// PIN / biometric gate shown before the app opens when a lock is
/// configured. SOS stays reachable from here — an emergency must never be
/// behind the lock (product spec §11).
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entered = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryBiometrics();
  }

  Future<void> _tryBiometrics() async {
    final service = ref.read(appLockServiceProvider);
    if (await service.biometricsEnabled && await service.biometricsAvailable) {
      final ok = await service.authenticateWithBiometrics();
      if (ok && mounted) _unlock();
    }
  }

  void _unlock() {
    ref.read(appLockStateProvider.notifier).unlock();
    context.go('/home');
  }

  Future<void> _digit(String d) async {
    if (_entered.length >= 8) return;
    setState(() {
      _entered += d;
      _error = null;
    });
    if (_entered.length >= 4) {
      final ok = await ref.read(appLockServiceProvider).verifyPin(_entered);
      if (ok && mounted) {
        _unlock();
      }
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit() async {
    final ok = await ref.read(appLockServiceProvider).verifyPin(_entered);
    if (ok) {
      if (mounted) _unlock();
    } else {
      setState(() {
        _entered = '';
        _error = 'Wrong PIN — try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: colors.emerald900,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.lock_outline, size: 48, color: colors.gold500),
            const SizedBox(height: AppSpacing.md),
            Text('Enter your PIN', style: typography.subtitle.copyWith(color: colors.ivory)),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 8; i++)
                  if (i < 4 || i < _entered.length + 1)
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _entered.length
                            ? colors.gold500
                            : colors.ivory.withValues(alpha: 0.25),
                      ),
                    ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: typography.small.copyWith(color: colors.warning)),
            ],
            const Spacer(),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['⌫', '0', '✓'],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final key in row)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: SizedBox(
                        width: 72,
                        height: 56,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.ivory,
                            side: BorderSide(color: colors.ivory.withValues(alpha: 0.3)),
                          ),
                          onPressed: () {
                            if (key == '⌫') {
                              _backspace();
                            } else if (key == '✓') {
                              _submit();
                            } else {
                              _digit(key);
                            }
                          },
                          child: Text(key, style: typography.subtitle.copyWith(color: colors.ivory)),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => context.push('/sos'),
              child: Text('Emergency SOS',
                  style: typography.body.copyWith(color: colors.danger, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
