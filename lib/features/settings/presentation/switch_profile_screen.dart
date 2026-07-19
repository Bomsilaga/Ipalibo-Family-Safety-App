import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/member_avatar.dart';
import 'child_profile_actions.dart';

/// "PIN/biometric against an already-registered family device session"
/// (docs/01-product-spec.md §4): this is that device session. Whoever is
/// currently signed in can hand the device to a child, who taps their name
/// and enters their PIN — child-sign-in Edge Function verifies it and
/// swaps the device's active Supabase session to the child's own identity.
/// Parents (who have a real password) set/reset PINs from here too.
///
/// This screen exists for discoverability from the More menu, but the same
/// actions are reachable directly from a member's row in the Family tab
/// (FamilyMembersScreen) — that's the more natural place to find "switch
/// to this profile" for most people.
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
                            onPressed: () => setChildPinFlow(context, ref, member),
                            child: const Text('Set PIN'),
                          )
                        : null,
                    onTap: member.role == UserRole.child && member.id != me?.id
                        ? () => signInAsChildFlow(context, ref, member)
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
}
