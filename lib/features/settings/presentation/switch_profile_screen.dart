import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/member_avatar.dart';

/// "PIN/biometric against an already-registered family device session"
/// (docs/01-product-spec.md §4): this is that device session. Whoever is
/// currently signed in can hand the device to a child, who taps their name
/// and enters their PIN — child-sign-in Edge Function verifies it and
/// swaps the device's active Supabase session to the child's own identity.
/// Parents (who have a real password) set/reset PINs from here too.
class SwitchProfileScreen extends ConsumerWidget {
  const SwitchProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final membersAsync = ref.watch(familyMembersProvider);
    final meAsync = ref.watch(currentAppUserProvider);
    final me = meAsync.value;

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('Switch Profile')),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const EmptyState(icon: Icons.people_outline, message: 'No family members yet.');
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'This device is signed in as ${me?.displayName ?? '...'}. '
                'Tap a child to hand them the device.',
                style: context.appTypography.small.copyWith(color: colors.gray[6]),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final member in members)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: MemberAvatar(user: member),
                    title: Text(member.displayName),
                    subtitle: Text(
                      member.id == me?.id ? '${member.role.toStringValue()} · this device' : member.role.toStringValue(),
                    ),
                    trailing: member.role == UserRole.child && me != null && me.role == UserRole.parent
                        ? TextButton(
                            onPressed: () => _setPin(context, ref, member),
                            child: const Text('Set PIN'),
                          )
                        : null,
                    onTap: member.role == UserRole.child && member.id != me?.id
                        ? () => _signInAsChild(context, ref, member)
                        : null,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/sign-in');
                },
                child: const Text('Sign in as a different parent'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(icon: Icons.error_outline, message: '$error'),
      ),
    );
  }

  Future<void> _signInAsChild(BuildContext context, WidgetRef ref, AppUser child) async {
    final pinController = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${child.displayName}\'s PIN'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter PIN'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, pinController.text), child: const Text('Continue')),
        ],
      ),
    );
    if (pin == null || pin.trim().isEmpty || !context.mounted) return;
    try {
      await ref.read(authRepositoryProvider).signInAsChild(childId: child.id, pin: pin.trim());
      ref.invalidate(currentAppUserProvider);
      if (context.mounted) context.go('/home');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _setPin(BuildContext context, WidgetRef ref, AppUser child) async {
    final pinController = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set PIN for ${child.displayName}'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          autofocus: true,
          decoration: const InputDecoration(hintText: '4-8 digit PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, pinController.text), child: const Text('Save')),
        ],
      ),
    );
    if (pin == null || !context.mounted) return;
    final trimmed = pin.trim();
    if (trimmed.length < 4 || trimmed.length > 8 || int.tryParse(trimmed) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be 4-8 digits')),
      );
      return;
    }
    try {
      await ref.read(authRepositoryProvider).setChildPin(childId: child.id, pin: trimmed);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PIN set for ${child.displayName}.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
