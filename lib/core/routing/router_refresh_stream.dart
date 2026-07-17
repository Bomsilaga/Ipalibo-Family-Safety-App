import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a [Stream] to go_router's `refreshListenable`, so the router
/// re-evaluates redirects whenever auth state changes.
class RouterRefreshStream extends ChangeNotifier {
  RouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
