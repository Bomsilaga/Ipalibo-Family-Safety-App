import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/calls_repository.dart';
import '../domain/call_model.dart';
import 'call_view_stub.dart' if (dart.library.js_interop) 'call_view_web.dart';

/// WhatsApp-style call screen: watches the shared `calls` row live so it
/// reacts to what everyone else does, not just local taps —
/// - if someone else answers first, "Ringing…" flips to a running timer
///   here too (see [CallsRepository.markActive]);
/// - if anyone hangs up (including the caller, from another device),
///   [CallsRepository.endCall] marks the row 'ended' and every open
///   CallScreen notices and closes itself, instead of sitting on a dead
///   Daily room forever.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, required this.callId, required this.roomUrl});

  final String callId;
  final String roomUrl;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  StreamSubscription<CallModel?>? _subscription;
  Timer? _ticker;
  CallModel? _call;
  DateTime? _activeSince;
  Duration _elapsed = Duration.zero;
  bool _markedActive = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(callsRepositoryProvider).watchCall(widget.callId).listen(_onCallUpdate);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeSince != null && mounted) {
        setState(() => _elapsed = DateTime.now().difference(_activeSince!));
      }
    });
  }

  void _onCallUpdate(CallModel? call) {
    if (call == null) return;
    setState(() => _call = call);

    if (call.isEnded) {
      _closeScreen();
      return;
    }

    // The person who *started* the call opens this same screen right
    // away too — only a second device joining should flip 'ringing' to
    // 'active'. Otherwise the very act of starting a call would
    // immediately mark it answered.
    final me = ref.read(currentAppUserProvider).value;
    if (call.isRinging && !_markedActive && me != null && me.id != call.createdBy) {
      _markedActive = true;
      ref.read(callsRepositoryProvider).markActive(widget.callId);
    }
    if (call.isActive) {
      _activeSince ??= DateTime.now();
    }
  }

  void _closeScreen() {
    if (_closing || !mounted) return;
    _closing = true;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/chat');
    }
  }

  Future<void> _hangUp() async {
    _closing = true;
    await ref.read(callsRepositoryProvider).endCall(widget.callId);
    if (mounted && context.canPop()) context.pop();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  String get _statusLabel {
    final call = _call;
    if (call == null) return 'Connecting…';
    if (call.isRinging) return 'Ringing…';
    if (call.isActive) {
      final m = _elapsed.inMinutes.toString().padLeft(2, '0');
      final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    return 'Call ended';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_closing) {
          _closing = true;
          ref.read(callsRepositoryProvider).endCall(widget.callId);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: CallView(roomUrl: widget.roomUrl)),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      onPressed: _hangUp,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
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
  const IncomingCallBanner({
    super.key,
    required this.callId,
    required this.roomUrl,
    required this.callerName,
    required this.isVideo,
    required this.isActive,
  });

  final String callId;
  final String roomUrl;
  final String callerName;
  final bool isVideo;
  final bool isActive;

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
                  isActive ? '$callerName started a call — in progress' : '$callerName is calling…',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              // Declining only silences this device — the call keeps
              // ringing for everyone else and for the caller, matching a
              // group call rather than ending it for the whole family.
              TextButton(
                onPressed: () => ref.read(dismissedCallsProvider.notifier).dismiss(callId),
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
