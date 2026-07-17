import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../data/rewards_repository.dart';

final _balanceProvider = FutureProvider<int>((ref) async {
  final me = await ref.watch(currentAppUserProvider.future);
  if (me == null) return 0;
  return ref.watch(rewardsRepositoryProvider).balance(me.id);
});

final _ledgerProvider = FutureProvider<List<LedgerEntry>>((ref) async {
  final me = await ref.watch(currentAppUserProvider.future);
  if (me == null) return const [];
  return ref.watch(rewardsRepositoryProvider).ledger(me.id);
});

/// Rewards: points balance, reward store (redeem with parent approval),
/// immutable ledger; parents can add rewards (product spec §12).
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final balanceAsync = ref.watch(_balanceProvider);
    final storeAsync = ref.watch(rewardStoreProvider);
    final ledgerAsync = ref.watch(_ledgerProvider);
    final me = ref.watch(currentAppUserProvider).value;
    final isParent = me != null && hasPermission(me, AppAction.manageRewards);

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('Rewards')),
      floatingActionButton: isParent
          ? FloatingActionButton(
              backgroundColor: colors.gold500,
              foregroundColor: colors.emerald900,
              child: const Icon(Icons.add),
              onPressed: () => _addReward(context, ref),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            color: colors.emerald900,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Text('Your points',
                      style: typography.small.copyWith(color: colors.ivory.withValues(alpha: 0.8))),
                  balanceAsync.when(
                    data: (b) => Text('$b',
                        style: typography.display.copyWith(color: colors.gold500)),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: CircularProgressIndicator(),
                    ),
                    error: (_, _) =>
                        Text('—', style: typography.display.copyWith(color: colors.gold500)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Reward store', style: typography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          storeAsync.when(
            data: (rewards) => rewards.isEmpty
                ? const EmptyState(
                    icon: Icons.card_giftcard_outlined,
                    message: 'No rewards yet — a parent can add some with +.')
                : Column(
                    children: [
                      for (final r in rewards)
                        Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            leading: Icon(Icons.card_giftcard_outlined, color: colors.gold500),
                            title: Text(r.title),
                            subtitle: Text('${r.pointCost} points'),
                            trailing: TextButton(
                              onPressed: () async {
                                await ref
                                    .read(rewardsRepositoryProvider)
                                    .requestRedemption(rewardId: r.id, userId: me!.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                      content: Text('Requested — waiting for parent approval.')));
                                }
                              },
                              child: const Text('Redeem'),
                            ),
                          ),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('$error'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('History', style: typography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          ledgerAsync.when(
            data: (entries) => entries.isEmpty
                ? const EmptyState(
                    icon: Icons.history, message: 'Points you earn and spend appear here.')
                : Column(
                    children: [
                      for (final e in entries)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            e.points >= 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                            color: e.points >= 0 ? colors.success : colors.danger,
                          ),
                          title: Text(e.reason),
                          trailing: Text(
                            '${e.points >= 0 ? '+' : ''}${e.points}',
                            style: typography.mono.copyWith(
                                color: e.points >= 0 ? colors.success : colors.danger),
                          ),
                        ),
                    ],
                  ),
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
          ),
        ],
      ),
    );
  }

  Future<void> _addReward(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final costController = TextEditingController(text: '50');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New reward'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: 'e.g. 30 min screen time')),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Point cost'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (saved != true) return;
    final me = await ref.read(currentAppUserProvider.future);
    final cost = int.tryParse(costController.text.trim());
    if (me?.familyId == null || titleController.text.trim().isEmpty || cost == null) return;
    await ref.read(rewardsRepositoryProvider).createReward(
          familyId: me!.familyId!,
          createdBy: me.id,
          title: titleController.text.trim(),
          pointCost: cost,
        );
    ref.invalidate(rewardStoreProvider);
  }
}
