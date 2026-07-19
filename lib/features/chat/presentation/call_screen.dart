import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/calls_repository.dart';
import 'call_view_stub.dart' if (dart.library.js_interop) 'call_view_web.dart';

class CallScreen extends ConsumerWidget {
  const CallScreen({super.key, required this.callId, required this.roomUrl});

  final String callId;
  final String roomUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(callsRepositoryProvider).endCall(callId);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: CallView(roomUrl: roomUrl)),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  onPressed: () async {
                    await ref.read(callsRepositoryProvider).endCall(callId);
                    if (context.mounted) context.pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Auto-answer note: Daily's room page already asks for camera/mic
/// permission and lets the joiner mute before entering, so there's no
/// separate "answer" step here — opening this screen *is* joining, same
/// as tapping a call link anywhere else.
class IncomingCallBanner extends ConsumerWidget {
  const IncomingCallBanner({super.key, required this.callId, required this.roomUrl, required this.callerName, required this.isVideo});

  final String callId;
  final String roomUrl;
  final String callerName;
  final bool isVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    return Material(
      elevation: 8,
      color: colors.emerald900,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(isVideo ? Icons.videocam : Icons.call, color: colors.gold500),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$callerName is calling…',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(callsRepositoryProvider).endCall(callId),
                child: const Text('Decline', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 4),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: colors.gold500, foregroundColor: colors.emerald900),
                onPressed: () => context.push('/call/$callId?roomUrl=${Uri.encodeComponent(roomUrl)}'),
                child: const Text('Join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
