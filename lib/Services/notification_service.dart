// notification_service.dart
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_launcher',
      [
        NotificationChannel(
          channelKey: 'download_progress_channel',
          channelName: 'Download Progress',
          channelDescription: 'Shows download progress notifications',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          playSound: false,
          enableVibration: false,
        ),
      ],
    );
  }

  Future<void> showProgressNotification({
    required int progress,
    required String title,
    required String body,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1,
          channelKey: 'download_progress_channel',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.ProgressBar,
          progress: progress.toDouble(),
          icon: 'resource://drawable/ic_launcher',
          locked: true,
        ),
      );
    } catch (e) {
      debugPrint('Error showing progress notification: $e');
    }
  }

  Future<void> showDownloadComplete({
    required String title,
    required String body,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1,
          channelKey: 'download_progress_channel',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
          icon: 'resource://drawable/ic_launcher',
          locked: false,
        ),
      );
    } catch (e) {
      debugPrint('Error showing completion notification: $e');
    }
  }

  Future<void> cancelNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
}
