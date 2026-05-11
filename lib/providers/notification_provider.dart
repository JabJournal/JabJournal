import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final _notificationService = NotificationService();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _notificationService.initialize();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  Future<void> showDoseReminder({
    required int id,
    required String peptideName,
    required double amountMcg,
  }) async {
    await _notificationService.showNotification(
      id: id,
      title: 'Time for $peptideName',
      body: 'Take your $amountMcg mcg dose now',
      payload: 'dose_reminder:$peptideName:$amountMcg',
    );
  }

  Future<void> scheduleDoseReminder({
    required int id,
    required String peptideName,
    required double amountMcg,
    required DateTime scheduledTime,
  }) async {
    await _notificationService.scheduleNotification(
      id: id,
      title: 'Time for $peptideName',
      body: 'Take your $amountMcg mcg dose now',
      scheduledTime: scheduledTime,
      payload: 'dose_reminder:$peptideName:$amountMcg',
    );
  }

  Future<void> cancelReminder(int id) async {
    await _notificationService.cancelNotification(id);
  }

  Future<void> cancelAllReminders() async {
    await _notificationService.cancelAllNotifications();
  }
}
