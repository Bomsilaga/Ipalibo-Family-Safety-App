import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../data/sos_repository.dart';

/// Emergency SOS: press and hold to trigger, so a pocket tap can't fire
/// it, but a frightened child can still send it in one motion.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  bool _sending = false;
  int? _notified;

  Future<void> _fire() async {
    setState(() {
      _sending = true;
      _notified = null;
    });
    try {
      final count = await ref.read(sosRepositoryProvider).sendSos();
      setState(() => _notified = count);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_notified != null) ...[
                Icon(Icons.check_circle_outline, size: 64, color: colors.success),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'SOS sent — $_notified parent${_notified == 1 ? '' : 's'} alerted.',
                  textAlign: TextAlign.center,
                  style: typography.subtitle,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              GestureDetector(
                onLongPress: _sending ? null : _fire,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.danger,
                    boxShadow: [
                      BoxShadow(
                        color: colors.danger.withValues(alpha: 0.4),
                        blurRadius: 32,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _sending
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('SOS',
                            style: typography.headline
                                .copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Press and hold to alert all parents with your location.',
                textAlign: TextAlign.center,
                style: typography.body.copyWith(color: colors.gray[6]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
