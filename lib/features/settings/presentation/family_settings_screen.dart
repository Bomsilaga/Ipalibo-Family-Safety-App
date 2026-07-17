import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';

/// Family settings, parent-only (product spec §15): quiet hours today;
/// notification categories, screen-time rules, data export, and security
/// settings attach here as their modules mature.
class FamilySettingsScreen extends ConsumerStatefulWidget {
  const FamilySettingsScreen({super.key});

  @override
  ConsumerState<FamilySettingsScreen> createState() => _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends ConsumerState<FamilySettingsScreen> {
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;
  bool _loaded = false;

  TimeOfDay? _parse(String? hhmmss) {
    if (hhmmss == null) return null;
    final parts = hhmmss.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String? _fmt(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _save(String familyId) async {
    await supabase.from('families').update({
      'quiet_hours_start': _fmt(_quietStart),
      'quiet_hours_end': _fmt(_quietEnd),
    }).eq('id', familyId);
    ref.invalidate(currentFamilyProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Quiet hours saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final familyAsync = ref.watch(currentFamilyProvider);
    final me = ref.watch(currentAppUserProvider).value;
    final isParent = me != null && hasPermission(me, AppAction.manageScreenTime);

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('Family Settings')),
      body: !isParent
          ? const EmptyState(
              icon: Icons.admin_panel_settings_outlined,
              message: 'Family settings are managed by parents.')
          : familyAsync.when(
              data: (family) {
                if (family == null) {
                  return const EmptyState(
                      icon: Icons.family_restroom_outlined, message: 'No family yet.');
                }
                if (!_loaded) {
                  _quietStart = _parse(family.quietHoursStart);
                  _quietEnd = _parse(family.quietHoursEnd);
                  _loaded = true;
                }
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text('Quiet hours', style: context.appTypography.subtitle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Non-emergency notifications are held until quiet hours end. SOS and unlock alerts always come through.',
                      style: context.appTypography.small.copyWith(color: colors.gray[6]),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final t = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      _quietStart ?? const TimeOfDay(hour: 21, minute: 0));
                              if (t != null) setState(() => _quietStart = t);
                            },
                            child: Text('From ${_quietStart?.format(context) ?? '—'}'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final t = await showTimePicker(
                                  context: context,
                                  initialTime: _quietEnd ?? const TimeOfDay(hour: 7, minute: 0));
                              if (t != null) setState(() => _quietEnd = t);
                            },
                            child: Text('To ${_quietEnd?.format(context) ?? '—'}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                        onPressed: () => _save(family.id), child: const Text('Save quiet hours')),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Timezone', style: context.appTypography.subtitle),
                    const SizedBox(height: AppSpacing.sm),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.public_outlined, color: colors.emerald700),
                        title: Text(family.timezone),
                        subtitle: const Text('Reminders fire in this timezone'),
                      ),
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
