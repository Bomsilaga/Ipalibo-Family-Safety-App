import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/settings/data/family_invite_repository.dart';
import '../../../features/settings/data/pending_invite.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../auth_providers.dart';

/// "Registration flow: create account → create family (name, avatar) or
/// accept an invite → set role" (docs/01-product-spec.md §4).
///
/// Two branches, and which one you get is decided for you rather than
/// asked: arriving with a pending invite (from an emailed/shared
/// `/join?code=…` link) drops you straight into the join branch with the
/// code already filled and your name pre-guessed from your email, so
/// accepting is one tap. Everyone else gets the create-a-family branch.
class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _familyNameController = TextEditingController();
  final _yourNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _isSubmitting = false;
  bool _joiningExisting = false;
  bool _fromInviteLink = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPendingInvite());
  }

  /// An invite link already told us the code — don't make them find the
  /// "have a code?" toggle and retype it.
  Future<void> _applyPendingInvite() async {
    final code = await ref.read(pendingInviteStoreProvider).read();
    if (code == null || code.isEmpty || !mounted) return;
    setState(() {
      _joiningExisting = true;
      _fromInviteLink = true;
      _inviteCodeController.text = code;
      // The email local-part is a decent first guess at a display name and
      // is editable right there — better than an empty required field
      // between them and their family.
      if (_yourNameController.text.isEmpty) {
        _yourNameController.text = _suggestedDisplayName();
      }
    });
  }

  String _suggestedDisplayName() {
    final email = ref.read(authRepositoryProvider).currentSession?.user.email ?? '';
    final local = email.split('@').first;
    if (local.isEmpty) return '';
    final cleaned = local.replaceAll(RegExp(r'[._\-\d]+'), ' ').trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  void dispose() {
    _familyNameController.dispose();
    _yourNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      if (_joiningExisting) {
        await ref.read(familyInviteRepositoryProvider).acceptInvite(
              code: _inviteCodeController.text.trim(),
              displayName: _yourNameController.text.trim(),
            );
        // Redeemed — make sure a stale code can't attach a later, unrelated
        // sign-up on this device to the same family.
        await ref.read(pendingInviteStoreProvider).clear();
        ref.invalidate(pendingInviteCodeProvider);
      } else {
        await ref.read(authRepositoryProvider).createFamilyAndBecomeParent(
              familyName: _familyNameController.text.trim(),
              displayName: _yourNameController.text.trim(),
            );
      }
      ref.invalidate(currentAppUserProvider);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: Text(_joiningExisting ? 'Join your family' : 'Create your family')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_fromInviteLink)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: colors.emerald700.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mark_email_read_outlined, color: colors.emerald700),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'You\'ve been invited to join a family. Confirm your name to finish.',
                            style: typography.small.copyWith(color: colors.emerald900),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  _joiningExisting ? 'Almost there' : 'Name your family',
                  style: typography.title.copyWith(color: colors.emerald900),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _joiningExisting
                      ? 'This is the name the rest of your family will see.'
                      : 'You\'ll be able to invite co-parents and add children next.',
                  style: typography.body.copyWith(color: colors.gray[6]),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_joiningExisting)
                  // Already filled from the link in the common case — kept
                  // visible and editable for anyone who was given a code
                  // verbally instead.
                  TextFormField(
                    controller: _inviteCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'Invite code'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Invite code is required' : null,
                  )
                else
                  TextFormField(
                    controller: _familyNameController,
                    decoration: const InputDecoration(hintText: 'Family name (e.g. The Ipalibos)'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Family name is required' : null,
                  ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _yourNameController,
                  decoration: const InputDecoration(hintText: 'Your display name'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Your name is required' : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_errorMessage!, style: typography.small.copyWith(color: colors.danger)),
                ],
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_joiningExisting ? 'Join Family' : 'Create Family'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _joiningExisting = !_joiningExisting;
                            _errorMessage = null;
                          }),
                  child: Text(
                    _joiningExisting
                        ? 'Creating a new family instead? Tap here'
                        : 'Have an invite code? Join a family instead',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
