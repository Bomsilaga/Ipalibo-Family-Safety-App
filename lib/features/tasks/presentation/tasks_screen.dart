import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';

/// Placeholder for Tasks — built out in Module 3 per docs/05-build-sequence.md.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.ivory,
      appBar: AppBar(title: const Text('Tasks')),
      body: const EmptyState(
        icon: Icons.checklist_outlined,
        message: 'No chores, homework, or reading assigned yet.',
      ),
    );
  }
}
