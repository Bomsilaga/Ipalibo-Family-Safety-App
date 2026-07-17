import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';

/// Placeholder for Calendar — built out in Module 2 per docs/05-build-sequence.md.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.ivory,
      appBar: AppBar(title: const Text('Calendar')),
      body: const EmptyState(
        icon: Icons.calendar_month_outlined,
        message: 'No appointments yet — tap + to add one.',
      ),
    );
  }
}
