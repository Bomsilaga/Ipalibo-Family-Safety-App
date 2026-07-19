import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_providers.dart';

/// Shared with `SwitchProfileScreen` — a child tapped anywhere in the app
/// (Family tab, Switch Profile) goes through the same PIN prompt and the
/// same `signInAsChild` call, so there's exactly one place this logic
/// lives.
Future<void> signInAsChildFlow(BuildContext context, WidgetRef ref, AppUser child) async {
  final pinController = TextEditingController();
  final pin = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${child.displayName}\'s PIN'),
      content: TextField(
        controller: pinController,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 8,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Enter PIN'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, pinController.text), child: const Text('Continue')),
      ],
    ),
  );
  if (pin == null || pin.trim().isEmpty || !context.mounted) return;
  try {
    await ref.read(authRepositoryProvider).signInAsChild(childId: child.id, pin: pin.trim());
    ref.invalidate(currentAppUserProvider);
    if (context.mounted) context.go('/home');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

Future<void> setChildPinFlow(BuildContext context, WidgetRef ref, AppUser child) async {
  final pinController = TextEditingController();
  final pin = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Set PIN for ${child.displayName}'),
      content: TextField(
        controller: pinController,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 8,
        autofocus: true,
        decoration: const InputDecoration(hintText: '4-8 digit PIN'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, pinController.text), child: const Text('Save')),
      ],
    ),
  );
  if (pin == null || !context.mounted) return;
  final trimmed = pin.trim();
  if (trimmed.length < 4 || trimmed.length > 8 || int.tryParse(trimmed) == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN must be 4-8 digits')),
    );
    return;
  }
  try {
    await ref.read(authRepositoryProvider).setChildPin(childId: child.id, pin: trimmed);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PIN set for ${child.displayName}.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
