import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';

/// Placeholder for Chat — built out in Module 5 per docs/05-build-sequence.md.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.ivory,
      appBar: AppBar(title: const Text('Chat')),
      body: const EmptyState(
        icon: Icons.chat_bubble_outline,
        message: 'Family chat opens here once messaging lands.',
      ),
    );
  }
}
