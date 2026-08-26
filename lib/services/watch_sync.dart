import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Bridges to the native iOS layer so the signed-in account's credentials can
/// be pushed to the paired Apple Watch companion app via WatchConnectivity.
///
/// All calls are best-effort and iOS-only: if there is no paired watch, the
/// companion app isn't installed, or connectivity is unavailable, the calls
/// fail silently rather than disrupting the login flow.
class WatchSync {
  const WatchSync._();

  static const MethodChannel _channel = MethodChannel('systems.unicore/watch');

  /// Sends [username] / [password] to the watch for standalone attendance use.
  static Future<void> syncCredentials(String username, String password) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('syncCredentials', {
        'username': username,
        'password': password,
      });
    } catch (_) {
      // No paired/reachable watch — ignore.
    }
  }

  /// Clears any credentials previously mirrored to the watch (on logout).
  static Future<void> clearCredentials() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('clearCredentials');
    } catch (_) {
      // Nothing to clear or watch unreachable — ignore.
    }
  }
}
