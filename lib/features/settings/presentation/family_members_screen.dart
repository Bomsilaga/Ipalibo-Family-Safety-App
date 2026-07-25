import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/member_avatar.dart';
import '../data/family_invite_repository.dart';
import 'child_profile_actions.dart';

/// Bottom-nav "Family" tab: family members and roles
/// (docs/01-product-spec.md §15 "Family settings (Parent-only): manage
/// members and roles").
class FamilyMembersScreen extends ConsumerWidget {
  const FamilyMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final appUserAsync = ref.watch(currentAppUserProvider);
    final familyAsync = ref.watch(currentFamilyProvider);
    final membersAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(
        title: familyAsync.when(
          data: (family) => Text(family?.name ?? 'Family'),
          loading: () => const Text('Family'),
          error: (_, _) => const Text('Family'),
        ),
      ),
      floatingActionButton: appUserAsync.maybeWhen(
        data: (user) => user != null && hasPermission(user, AppAction.inviteMember)
            ? FloatingActionButton(
                backgroundColor: colors.gold500,
                foregroundColor: colors.emerald900,
                onPressed: () => _openAddMemberSheet(context, ref, user),
                child: const Icon(Icons.person_add_alt_1_outlined),
              )
            : null,
        orElse: () => null,
      ),
      body: appUserAsync.when(
        data: (user) => user == null
            ? const EmptyState(icon: Icons.family_restroom_outlined, message: 'Sign in to see your family.')
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You', style: typography.small.copyWith(color: colors.gray[6])),
                    const SizedBox(height: AppSpacing.sm),
                    Card(
                      child: ListTile(
                        leading: MemberAvatar(user: user),
                        title: Text(user.displayName),
                        subtitle: Text(user.role.toStringValue()),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Other members', style: typography.small.copyWith(color: colors.gray[6])),
                    const SizedBox(height: 2),
                    Text(
                      'Tap a member to switch this device to their profile.',
                      style: typography.caption.copyWith(color: colors.gray[5]),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: membersAsync.when(
                        data: (members) {
                          final others = members.where((m) => m.id != user.id).toList();
                          if (others.isEmpty) {
                            return const EmptyState(
                              icon: Icons.group_add_outlined,
                              message: 'Invite a co-parent or add a child to get started.',
                            );
                          }
                          return ListView(
                            children: [
                              for (final m in others)
                                Card(
                                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: ListTile(
                                    leading: MemberAvatar(user: m),
                                    title: Text(m.displayName),
                                    subtitle: Text(m.role.toStringValue()),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _openMemberOptions(context, ref, user, m),
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, _) => EmptyState(icon: Icons.error_outline, message: '$error'),
                      ),
                    ),
                  ],
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(icon: Icons.error_outline, message: '$error'),
      ),
    );
  }

  Future<void> _openMemberOptions(BuildContext context, WidgetRef ref, AppUser me, AppUser member) async {
    final isParentViewer = me.role == UserRole.parent;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: MemberAvatar(user: member),
              title: Text(member.displayName),
              subtitle: Text(member.role.toStringValue()),
            ),
            const Divider(height: 1),
            if (member.role == UserRole.child) ...[
              ListTile(
                leading: const Icon(Icons.switch_account_outlined),
                title: const Text('Switch to this profile'),
                subtitle: const Text('Hand the device to them — asks for their PIN'),
                onTap: () {
                  Navigator.pop(ctx);
                  signInAsChildFlow(context, ref, member);
                },
              ),
              if (isParentViewer)
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Set / reset PIN'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setChildPinFlow(context, ref, member);
                  },
                ),
            ] else
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text('Co-parent — role management coming soon.'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddMemberSheet(BuildContext context, WidgetRef ref, AppUser me) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Invite a co-parent'),
              subtitle: const Text('Generates a code to share with them'),
              onTap: () => Navigator.pop(ctx, 'invite'),
            ),
            ListTile(
              leading: const Icon(Icons.child_care_outlined),
              title: const Text('Add a child'),
              subtitle: const Text('Generates a code for them to join with their own email'),
              onTap: () => Navigator.pop(ctx, 'child'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'invite') {
      await _generateInviteFlow(
        context,
        ref,
        me,
        role: 'parent',
        dialogTitle: 'Invite a co-parent',
        emailHint: 'Their email',
      );
    } else {
      await _generateInviteFlow(
        context,
        ref,
        me,
        role: 'child',
        dialogTitle: 'Add a child',
        emailHint: "Child's email",
      );
    }
  }

  /// Shared by "Invite a co-parent" and "Add a child" — both join an
  /// *existing* family the same way (docs/06-deviations.md "founder
  /// bootstrap"): a parent generates a code here, the invitee creates
  /// their own account with their own email on the sign-in screen, then
  /// redeems the code on the family-setup screen's "I have an invite
  /// code" branch. accept-invite assigns whatever role the invite
  /// carries, so a child invite is identical to a co-parent invite
  /// except role: 'child' — children now sign in with their own
  /// email/password like everyone else, not a parent-set device PIN.
  Future<void> _generateInviteFlow(
    BuildContext context,
    WidgetRef ref,
    AppUser me, {
    required String role,
    required String dialogTitle,
    required String emailHint,
  }) async {
    if (me.familyId == null) return;
    final emailController = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dialogTitle),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(hintText: emailHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate code')),
        ],
      ),
    );
    // family_invites requires an email or phone on the row (there's no
    // delivery mechanism yet, but it's how a parent tells invites apart).
    if (proceed != true || emailController.text.trim().isEmpty || !context.mounted) return;
    try {
      final code = await ref.read(familyInviteRepositoryProvider).createInvite(
            familyId: me.familyId!,
            invitedBy: me.id,
            role: role,
            email: emailController.text.trim(),
          );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invite code ready'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role == 'child'
                    ? 'Share this code with them. On their own device, they\'ll create an account with their email, then enter this code to join your family:'
                    : 'Share this code with them. They\'ll enter it after creating their account:',
              ),
              const SizedBox(height: AppSpacing.md),
              SelectableText(
                code,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Expires in 7 days.', style: context.appTypography.caption),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Code copied')));
              },
              child: const Text('Copy'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create invite: $e')));
      }
    }
  }
}
