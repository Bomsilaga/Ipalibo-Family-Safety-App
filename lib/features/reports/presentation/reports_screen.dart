import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/member_avatar.dart';

class _ChildReport {
  const _ChildReport({required this.child, required this.completed, required this.total, required this.points});

  final AppUser child;
  final int completed;
  final int total;
  final int points;

  double get rate => total == 0 ? 0 : completed / total;
}

/// Per-child completion over the trailing 7 days + reward totals — the
/// weekly report slice of product spec §14. PDF/CSV export follows once
/// the aggregation views move server-side.
final _weeklyReportsProvider = FutureProvider<List<_ChildReport>>((ref) async {
  final members = await ref.watch(familyMembersProvider.future);
  final children = members.where((m) => m.role == UserRole.child).toList();
  final weekAgo =
      DateTime.now().subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);

  final reports = <_ChildReport>[];
  for (final child in children) {
    final completions = await supabase
        .from('task_completions')
        .select('status')
        .eq('user_id', child.id)
        .gte('scheduled_date', weekAgo);
    final rows = (completions as List).cast<Map<String, dynamic>>();
    final completed =
        rows.where((r) => r['status'] == 'completed' || r['status'] == 'approved').length;

    final ledger =
        await supabase.from('reward_ledger').select('points').eq('user_id', child.id);
    final points = (ledger as List)
        .cast<Map<String, dynamic>>()
        .fold<int>(0, (sum, r) => sum + (r['points'] as int));

    reports.add(_ChildReport(child: child, completed: completed, total: rows.length, points: points));
  }
  return reports;
});

/// Parent-only weekly report (permission matrix: "View reports — Parent").
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final typography = context.appTypography;
    final reportsAsync = ref.watch(_weeklyReportsProvider);

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('Reports')),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return const EmptyState(
              icon: Icons.bar_chart_outlined,
              message: 'Reports appear once children have tasks to complete.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('This week', style: typography.subtitle),
              const SizedBox(height: AppSpacing.sm),
              for (final r in reports)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            MemberAvatar(user: r.child, radius: 16),
                            const SizedBox(width: AppSpacing.sm),
                            Text(r.child.displayName, style: typography.bodyLarge),
                            const Spacer(),
                            Text('${r.points} pts',
                                style: typography.mono.copyWith(color: colors.gold500)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        LinearProgressIndicator(
                          value: r.rate,
                          backgroundColor: colors.gray[2],
                          color: r.rate >= 0.8 ? colors.success : colors.warning,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${r.completed} of ${r.total} tasks completed',
                          style: typography.caption.copyWith(color: colors.gray[6]),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            EmptyState(icon: Icons.error_outline, message: 'Could not build reports: $error'),
      ),
    );
  }
}
