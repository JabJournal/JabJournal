import 'package:flutter/material.dart';
import '../services/supabase/sync_manager.dart';

class SyncProvider with ChangeNotifier {
  final _syncManager = SyncManager();

  bool _isOnline = true;
  bool _isSyncing = false;
  String? _syncError;
  DateTime? _lastSyncTime;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  DateTime? get lastSyncTime => _lastSyncTime;

  void initialize() {
    _syncManager.connectionStatus.listen((isOnline) {
      _isOnline = isOnline;
      notifyListeners();

      if (isOnline && !_isSyncing) {
        syncAll();
      }
    });

    _checkOnlineStatus();
  }

  Future<void> _checkOnlineStatus() async {
    _isOnline = await _syncManager.isOnline();
    notifyListeners();
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      await _syncManager.syncAll();
      _lastSyncTime = DateTime.now();
      _syncError = null;
    } catch (e) {
      _syncError = 'Sync failed: $e';
      debugPrint(_syncError);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void clearSyncError() {
    _syncError = null;
    notifyListeners();
  }
}
