import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';

/// Bottom-nav "Family" tab: family members and roles
/// (docs/01-product-spec.md §15 "Family settings (Parent-only): manage
/// members and roles"). Member CRUD (invite, promote, create child) lands
/// with the rest of Module 1's registration flow follow-ups; this wires the
/// shell to live `currentAppUserProvider`/`currentFamilyProvider` data.
class FamilyMembersScreen extends ConsumerWidget {
  const FamilyMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final appUserAsync = ref.watch(currentAppUserProvider);
    final familyAsync = ref.watch(currentFamilyProvider);

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
                onPressed: () {},
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
                        leading: CircleAvatar(
                          backgroundColor: Color(
                            int.parse(user.avatarColor.replaceFirst('#', 'FF'), radix: 16),
                          ),
                          child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?'),
                        ),
                        title: Text(user.displayName),
                        subtitle: Text(user.role.toStringValue()),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Other members', style: typography.small.copyWith(color: colors.gray[6])),
                    const SizedBox(height: AppSpacing.sm),
                    const Expanded(
                      child: EmptyState(
                        icon: Icons.group_add_outlined,
                        message: 'Invite a co-parent or add a child to get started.',
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
}
