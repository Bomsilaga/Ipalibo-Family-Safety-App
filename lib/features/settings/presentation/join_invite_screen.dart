import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../data/pending_invite.dart';

/// Landing spot for an invite link (`/join?code=…`) — the destination of
/// the "You've been invited" email and of any link a parent shares by
/// hand.
///
/// It never asks for the code: it stashes it (see [PendingInviteStore],
/// which survives the sign-up email round trip) and then gets out of the
/// way. Where it sends people depends on where they already are:
///
///  - already in a family  → nothing to join, straight Home;
///  - signed in, no family → `/family-setup`, which sees the pending code
///    and joins them automatically;
///  - signed out           → `/sign-in`, which shows an invite banner so
///    it's obvious why they're being asked to make an account.
///
/// Supabase's invite email signs the user in as part of following the
/// link, so the common path is the second one and the invitee never types
/// a code at all.
class JoinInviteScreen extends ConsumerStatefulWidget {
  const JoinInviteScreen({super.key, required this.code});

  final String? code;

  @override
  ConsumerState<JoinInviteScreen> createState() => _JoinInviteScreenState();
}

class _JoinInviteScreenState extends ConsumerState<JoinInviteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle());
  }

  Future<void> _handle() async {
    final code = widget.code?.trim();
    if (code != null && code.isNotEmpty) {
      await ref.read(pendingInviteStoreProvider).save(code);
      ref.invalidate(pendingInviteCodeProvider);
    }
    if (!mounted) return;

    // The invite link doubles as a sign-in link, so the session may only
    // have just landed — wait for the user lookup rather than racing it.
    final me = await ref.read(currentAppUserProvider.future);
    if (!mounted) return;

    if (me?.familyId != null) {
      context.go('/home');
    } else if (ref.read(authRepositoryProvider).currentSession != null) {
      context.go('/family-setup');
    } else {
      context.go('/sign-in');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.ivory,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Opening your invite…',
              style: context.appTypography.body.copyWith(color: colors.gray[6]),
            ),
          ],
        ),
      ),
    );
  }
}
