import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/settings/data/family_invite_repository.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../auth_providers.dart';

/// "Registration flow: create account → create family (name, avatar) or
/// accept an invite → set role" (docs/01-product-spec.md §4). This screen
/// covers the "create family" branch; the caller becomes the founding
/// Parent.
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
  String? _errorMessage;

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
                Text(
                  _joiningExisting ? 'Enter your invite code' : 'Name your family',
                  style: typography.title.copyWith(color: colors.emerald900),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _joiningExisting
                      ? 'Ask the parent who invited you for the 8-character code.'
                      : 'You\'ll be able to invite co-parents and add children next.',
                  style: typography.body.copyWith(color: colors.gray[6]),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_joiningExisting)
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
