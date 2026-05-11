import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/foreground_service.dart';

/// Tracks whether the user has opted into the persistent background service
/// that keeps the app alive for reliable scheduled notifications. Persists
/// the preference across launches.
class ForegroundServiceProvider with ChangeNotifier {
  static const _prefKey = 'foreground_service_enabled';

  bool _enabled = false;
  bool _running = false;
  bool _loaded = false;

  /// Whether the user wants the foreground service running.
  bool get enabled => _enabled;

  /// Whether the OS reports the service as actually running.
  bool get running => _running;

  bool get isLoaded => _loaded;

  /// Only meaningful on Android — iOS handles backgrounding differently.
  bool get isSupported => Platform.isAndroid;

  Future<void> load() async {
    if (!isSupported) {
      _loaded = true;
      notifyListeners();
      return;
    }

    PeptideForegroundService.init();
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? false;
    _running = await PeptideForegroundService.isRunning();

    // If the user enabled it previously but the service isn't running (e.g.
    // after a reboot before autoRunOnBoot kicks in), start it.
    if (_enabled && !_running) {
      await _start();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (!isSupported) return;
    if (_enabled == value) return;

    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);

    if (value) {
      await _start();
    } else {
      await _stop();
    }
    notifyListeners();
  }

  /// Re-reads OS state — call after app resume in case the service was
  /// killed externally.
  Future<void> refresh() async {
    if (!isSupported) return;
    _running = await PeptideForegroundService.isRunning();
    notifyListeners();
  }

  Future<void> _start() async {
    final ok = await PeptideForegroundService.start();
    _running = ok;
  }

  Future<void> _stop() async {
    final ok = await PeptideForegroundService.stop();
    _running = !ok;
  }
}
