import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';

/// Placeholder for GPS Safety (Live Location) — built out in Module 7 per
/// docs/05-build-sequence.md. Reached from the "More" tab, not a top-level
/// bottom-nav destination (docs/04-design-system.md "Mobile navigation").
class GpsScreen extends StatelessWidget {
  const GpsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.ivory,
      appBar: AppBar(title: const Text('Live Location')),
      body: const EmptyState(
        icon: Icons.map_outlined,
        message: 'Live locations and safe zones will appear here.',
      ),
    );
  }
}
