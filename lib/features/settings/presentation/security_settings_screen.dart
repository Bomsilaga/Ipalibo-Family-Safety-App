import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_lock_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';

/// Personal security settings: device PIN (shared/child devices) and
/// biometric unlock (product spec §4, §15 "Personal settings").
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _pinSet = false;
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final service = ref.read(appLockServiceProvider);
    final pinSet = await service.isPinSet;
    final bioEnabled = await service.biometricsEnabled;
    final bioAvailable = await service.biometricsAvailable;
    if (!mounted) return;
    setState(() {
      _pinSet = pinSet;
      _biometricsEnabled = bioEnabled;
      _biometricsAvailable = bioAvailable;
      _loading = false;
    });
  }

  Future<void> _setPin() async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_pinSet ? 'Change PIN' : 'Set a PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              decoration: const InputDecoration(hintText: '4-8 digit PIN'),
            ),
            TextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              decoration: const InputDecoration(hintText: 'Confirm PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text != confirmController.text) return;
              Navigator.pop(ctx, controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (pin == null) return;
    if (!AppLockService.isValidPin(pin)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('PIN must be 4-8 digits.')));
      }
      return;
    }
    await ref.read(appLockServiceProvider).setPin(pin);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('Security')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(Icons.pin_outlined, color: colors.emerald700),
                    title: Text(_pinSet ? 'Change PIN' : 'Set app PIN'),
                    subtitle: const Text('Required to open the app on this device'),
                    onTap: _setPin,
                  ),
                ),
                if (_pinSet)
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.lock_open_outlined, color: colors.danger),
                      title: const Text('Remove PIN'),
                      onTap: () async {
                        await ref.read(appLockServiceProvider).clearPin();
                        await _refresh();
                      },
                    ),
                  ),
                Card(
                  child: SwitchListTile(
                    secondary: Icon(Icons.fingerprint, color: colors.emerald700),
                    title: const Text('Biometric unlock'),
                    subtitle: Text(
                      _biometricsAvailable
                          ? 'Use Face ID / fingerprint instead of the PIN'
                          : 'Not available on this device',
                    ),
                    value: _biometricsEnabled && _biometricsAvailable && _pinSet,
                    onChanged: _biometricsAvailable && _pinSet
                        ? (v) async {
                            await ref.read(appLockServiceProvider).setBiometricsEnabled(v);
                            await _refresh();
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'The PIN is stored only on this device (salted and hashed in the platform keystore). It gates the app, not your account — signing in again on a new device uses your normal credentials.',
                  style: context.appTypography.caption.copyWith(color: colors.gray[6]),
                ),
              ],
            ),
    );
  }
}
