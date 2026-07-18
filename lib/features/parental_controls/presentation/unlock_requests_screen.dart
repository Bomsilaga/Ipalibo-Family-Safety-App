import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../data/unlock_repository.dart';
import '../domain/unlock_request_model.dart';

/// Unlock Requests, both sides of the lifecycle (product spec §8):
/// - Parent: pending requests with "Generate Unlock Code" (gold primary
///   action per the mockup) and Decline; recent history below.
/// - Child: "Request Unlock" with a reason picker; enter-code flow for an
///   approved request.
class UnlockRequestsScreen extends ConsumerWidget {
  const UnlockRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final meAsync = ref.watch(currentAppUserProvider);
    final requestsAsync = ref.watch(unlockRequestsProvider);

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('Unlock Requests')),
      body: meAsync.when(
        data: (me) {
          if (me == null) {
            return const EmptyState(icon: Icons.lock_outline, message: 'Sign in first.');
          }
          final isParent = me.role == UserRole.parent;
          return requestsAsync.when(
            data: (requests) => _RequestList(me: me, isParent: isParent, requests: requests),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                EmptyState(icon: Icons.error_outline, message: 'Could not load: $error'),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(icon: Icons.error_outline, message: '$error'),
      ),
    );
  }
}

class _RequestList extends ConsumerWidget {
  const _RequestList({required this.me, required this.isParent, required this.requests});

  final AppUser me;
  final bool isParent;
  final List<UnlockRequest> requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final members = {
      for (final m in ref.watch(familyMembersProvider).value ?? <AppUser>[]) m.id: m,
    };
    final pending = requests.where((r) => r.isPending).toList();
    final history = requests.where((r) => !r.isPending).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (!isParent) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: colors.emerald700),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Need your device unlocked?',
                      textAlign: TextAlign.center, style: typography.subtitle),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () => _requestUnlock(context, ref),
                    child: const Text('Request Unlock'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (pending.isNotEmpty) ...[
          Text('Pending', style: typography.small.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          for (final r in pending)
            _RequestCard(request: r, requester: members[r.childId], isParent: isParent, me: me),
        ],
        if (pending.isEmpty && !isParent)
          const SizedBox()
        else if (pending.isEmpty)
          const EmptyState(
              icon: Icons.lock_open_outlined, message: 'No pending unlock requests. All calm.'),
        if (history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Recent', style: typography.small.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          for (final r in history.take(10))
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: Icon(
                  switch (r.status) {
                    'approved' || 'temporary' => Icons.lock_open_outlined,
                    'rejected' => Icons.block_outlined,
                    _ => Icons.timer_off_outlined,
                  },
                  color: switch (r.status) {
                    'approved' || 'temporary' => colors.success,
                    'rejected' => colors.danger,
                    _ => colors.gray[5],
                  },
                ),
                title: Text(members[r.childId]?.displayName ?? 'Unknown'),
                subtitle: Text('${r.reason ?? 'No reason'} · ${r.status}'),
                trailing: !isParent && r.status == 'approved' && r.codeUsedAt == null
                    ? TextButton(
                        onPressed: () => _enterCode(context, ref, r),
                        child: const Text('Enter code'),
                      )
                    : null,
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _requestUnlock(BuildContext context, WidgetRef ref) async {
    final reasons = ['Finished my task', 'Homework research', 'Call a parent', 'Other'];
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Why do you need it unlocked?'),
        children: [
          for (final r in reasons)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, r), child: Text(r)),
        ],
      ),
    );
    if (reason == null) return;
    await ref.read(unlockRepositoryProvider).requestUnlock(
          familyId: me.familyId!,
          childId: me.id,
          reason: reason,
        );
    ref.invalidate(unlockRequestsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request sent — your parent has been notified.')));
    }
  }

  Future<void> _enterCode(BuildContext context, WidgetRef ref, UnlockRequest request) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter unlock code'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: '6-digit code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Unlock')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      await ref.read(unlockRepositoryProvider).redeemCode(requestId: request.id, code: code);
      ref.invalidate(unlockRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Unlocked! Restriction lifted.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({
    required this.request,
    required this.requester,
    required this.isParent,
    required this.me,
  });

  final UnlockRequest request;
  final AppUser? requester;
  final bool isParent;
  final AppUser me;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final name = widget.requester?.displayName ?? 'Someone';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("$name's device is locked", style: typography.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(widget.request.reason ?? 'No reason given',
                style: typography.body.copyWith(color: colors.gray[6])),
            if (widget.isParent) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy ? null : _generate,
                      child: const Text('Generate Unlock Code'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    child: const Text('Decline'),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text('Waiting for a parent to review…',
                    style: typography.caption.copyWith(color: colors.gray[5])),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final result =
          await ref.read(unlockRepositoryProvider).generateCode(widget.request.id);
      ref.invalidate(unlockRequestsProvider);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Unlock code'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(result.code,
                    style: context.appTypography.headline
                        .copyWith(color: context.appColors.emerald900, letterSpacing: 8)),
                const SizedBox(height: AppSpacing.sm),
                const Text('Share this with your child. It works once and expires in 5 minutes.'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await ref.read(unlockRepositoryProvider).reject(widget.request.id);
      ref.invalidate(unlockRequestsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
