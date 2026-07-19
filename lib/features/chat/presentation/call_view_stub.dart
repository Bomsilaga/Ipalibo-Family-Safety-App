import 'package:flutter/material.dart';

/// Fallback for non-web builds — native mobile calling needs Daily's
/// dedicated Flutter SDK (platform channels, not a web view), which is a
/// follow-up once this ships to iOS/Android. See docs/06-deviations.md.
class CallView extends StatelessWidget {
  const CallView({super.key, required this.roomUrl});

  final String roomUrl;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Calls are available on the web app for now — native mobile calling is a follow-up.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
