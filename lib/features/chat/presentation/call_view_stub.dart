import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Native (Android/iOS) call view. The web build swaps this out for
/// `call_view_web.dart`, which uses an iframe instead.
///
/// Daily's room page is already a complete prebuilt call UI, so the whole
/// native integration is loading that URL in a WebView with camera/mic
/// forwarded — no Daily SDK needed. (This replaces the old placeholder
/// that told mobile users to go use the web app.)
///
/// The thing that makes or breaks it is `setOnPlatformPermissionRequest`:
/// an Android WebView denies `getUserMedia` by default, so without
/// granting it the room loads fine but the camera and mic stay dead —
/// which looks identical to a broken call. Note this only forwards the
/// request; the app-level CAMERA/RECORD_AUDIO runtime permissions still
/// have to be granted by the user first.
class CallView extends StatefulWidget {
  const CallView({super.key, required this.roomUrl});

  final String roomUrl;

  @override
  State<CallView> createState() => _CallViewState();
}

class _CallViewState extends State<CallView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse(widget.roomUrl));

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _controller.platform as AndroidWebViewController;
      // The other participant's audio/video must be allowed to start
      // without a tap, or the call is silent until the user touches the
      // video.
      android.setMediaPlaybackRequiresUserGesture(false);
      android.setOnPlatformPermissionRequest((request) => request.grant());
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
