import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Embeds the Daily.co room directly — Daily's own room page is already a
/// full prebuilt call UI (video, audio, mute, screen share), so an iframe
/// is the entire integration on web. No client SDK, no API key on this
/// side at all.
class CallView extends StatefulWidget {
  const CallView({super.key, required this.roomUrl});

  final String roomUrl;

  @override
  State<CallView> createState() => _CallViewState();
}

class _CallViewState extends State<CallView> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'daily-call-${widget.roomUrl.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return html.IFrameElement()
        ..src = widget.roomUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'camera; microphone; fullscreen; display-capture; autoplay';
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
