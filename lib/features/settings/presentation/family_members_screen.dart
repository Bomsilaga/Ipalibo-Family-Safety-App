import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

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
                onPressed: () => _addFamilyMemberFlow(context, ref, user),
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
                              message: 'Tap the + button to add a co-parent or child.',
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
            if (isParentViewer) ...[
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.person_remove_outlined, color: context.appColors.danger),
                title: Text(
                  'Remove from family',
                  style: TextStyle(color: context.appColors.danger),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmRemoveMember(context, ref, member);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveMember(BuildContext context, WidgetRef ref, AppUser member) async {
    final colors = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${member.displayName}?'),
        content: Text(
          'They lose access to your family\'s calendar, tasks, chat and location straight away, '
          'and their location history and notifications are deleted.\n\n'
          'Shared history — messages they sent, chores they completed — stays. '
          'You can invite them back at any time.',
          style: context.appTypography.body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(familyInviteRepositoryProvider).removeMember(member.id);
      ref.invalidate(familyMembersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.displayName} removed from your family.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  /// One dialog for both roles — a parent and a child join a family the
  /// exact same way (docs/06-deviations.md "founder bootstrap"): pick who
  /// this is for, type their email, done. The `invite-member` function
  /// emails them a link that signs them in and drops them straight into
  /// the family, so in the happy path nobody reads out or types a code.
  Future<void> _addFamilyMemberFlow(BuildContext context, WidgetRef ref, AppUser me) async {
    if (me.familyId == null) return;
    final emailController = TextEditingController();
    String role = 'child';
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add a family member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Who is this for?'),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'child', label: Text('Child'), icon: Icon(Icons.child_care_outlined)),
                  ButtonSegment(value: 'parent', label: Text('Co-parent'), icon: Icon(Icons.person_outline)),
                ],
                selected: {role},
                onSelectionChanged: (selection) => setState(() => role = selection.first),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Their email'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'We\'ll email them a link that adds them to your family.',
                style: context.appTypography.caption,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send invite')),
          ],
        ),
      ),
    );
    if (proceed != true || emailController.text.trim().isEmpty || !context.mounted) return;

    // showDialog pushes onto the ROOT navigator by default, but this
    // screen sits inside a StatefulShellRoute branch, so its own context
    // resolves to the *branch* navigator. Popping via the screen context
    // therefore dismissed the /family page instead of the spinner and
    // emptied the branch stack — a white screen with no error. Hold the
    // same navigator the dialog was pushed to and pop that.
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    InviteResult? result;
    Object? failure;
    try {
      result = await ref.read(familyInviteRepositoryProvider).inviteMember(
            email: emailController.text.trim(),
            role: role,
          );
    } catch (e) {
      failure = e;
    }

    if (rootNavigator.canPop()) rootNavigator.pop(); // dismiss the spinner
    if (!context.mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not send invite: $failure')));
      return;
    }
    await _showInviteResult(context, result!);
  }

  /// Always offers the link, even on a successful send: Supabase's
  /// built-in SMTP is rate-limited, so "sent" isn't the same as
  /// "arrived", and a parent standing next to their kid would rather just
  /// share it directly anyway.
  Future<void> _showInviteResult(BuildContext context, InviteResult result) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(switch (result.emailed) {
          true => 'Invite sent',
          false => 'Invite ready to share',
          null => 'Invite created',
        }),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (result.emailed) {
              true => 'We emailed ${result.email}. They tap the link and they\'re in — no code to type.',
              false =>
                'We couldn\'t email ${result.email} right now, so send them this link instead. It adds them to your family when they open it.',
              // Still sending — don't claim it arrived, don't claim it
              // failed. The link works either way.
              null =>
                'We\'re emailing ${result.email} now. You can also send them this link yourself — it adds them to your family when they open it.',
            }),
            const SizedBox(height: AppSpacing.md),
            SelectableText(result.link, style: context.appTypography.small),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Backup code: ${result.code} · expires in 7 days',
              style: context.appTypography.caption,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result.link));
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Link copied')));
            },
            child: const Text('Copy link'),
          ),
          TextButton(
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: 'Join our family on The Ipalibos: ${result.link}'),
            ),
            child: const Text('Share'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }
}
