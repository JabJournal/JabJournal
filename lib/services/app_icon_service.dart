import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppIconService {
  static const _ch = MethodChannel('app.jabjournal/icon');

  // Supported on iOS (UIApplication.setAlternateIconName) and Android
  // (activity-alias via PackageManager).
  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  // Returns the active variant name ("forest", "amethyst", "slate"),
  // or null when the default (Ocean) icon is active.
  static Future<String?> currentIcon() async {
    if (!isSupported) return null;
    return _ch.invokeMethod<String?>('getIcon');
  }

  // Pass null to restore the default Ocean icon.
  static Future<void> setIcon(String? variant) async {
    if (!isSupported) return;
    await _ch.invokeMethod<void>('setIcon', variant);
  }
}
