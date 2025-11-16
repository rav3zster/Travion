import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  // Player used when an alarm is playing. Kept so we can stop it when needed.
  static AudioPlayer? _currentAlarmPlayer;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification tapped: ${details.payload}');
        },
      );

      // Request permissions for Android 13+
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
      // Don't throw - allow app to continue
    }
  }

  /// Show a proximity alert notification
  static Future<void> showProximityAlert({
    required String title,
    required String body,
    int? distance,
    bool playSound = true,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'proximity_alerts',
      'Proximity Alerts',
      channelDescription: 'Notifications when approaching destination',
      importance: Importance.high,
      priority: Priority.high,
      playSound: playSound,
      // Use default sound instead of custom resource
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: distance != null ? '${distance}m away' : null,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0, // notification id
      title,
      body,
      details,
      payload: 'proximity_alert_$distance',
    );
  }

  /// Show a critical alarm notification (max priority)
  static Future<void> showAlarmNotification({
    required String title,
    required String body,
    int? distance,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'alarm_alerts',
      'Alarm Alerts',
      channelDescription: 'Critical alarm when reaching destination radius',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      // Use default sound instead of custom resource
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      autoCancel: false,
      ongoing: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText:
            distance != null ? '${distance}m away' : 'DESTINATION ALERT',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // Use default sound
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1, // alarm notification id
      title,
      body,
      details,
      payload: 'alarm_$distance',
    );

    // After showing the system notification, attempt to play user-selected alarm
    // or launch an external app/uri as configured by the user.
    _playAlarmSoundIfConfigured();
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    try {
      await _notifications.cancelAll();
      await stopAlarmPlayback();
    } catch (e) {
      debugPrint('Error canceling notifications: $e');
    }
  }

  /// Cancel specific notification
  static Future<void> cancel(int id) async {
    try {
      await _notifications.cancel(id);
      if (id == 1) {
        // If canceling alarm notification, stop playback
        await stopAlarmPlayback();
      }
    } catch (e) {
      debugPrint('Error canceling notification $id: $e');
    }
  }

  /// Try to play an alarm sound if the user configured a local file or launch
  /// an external URI (Spotify, etc.) as a fallback.
  static Future<void> _playAlarmSoundIfConfigured() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('alarm_sound_path');
      final external = prefs.getString('alarm_external_uri');

      if (path != null && path.isNotEmpty) {
        // Play the selected local file in loop until stopped.
        _currentAlarmPlayer ??= AudioPlayer();
        await _currentAlarmPlayer!.setReleaseMode(ReleaseMode.loop);
        // Some platforms expect DeviceFileSource
        await _currentAlarmPlayer!.play(DeviceFileSource(path));
      } else if (external != null && external.isNotEmpty) {
        final uri = Uri.tryParse(external);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e, st) {
      debugPrint(
          'Error playing alarm sound or launching external uri: $e\n$st');
    }
  }

  /// Stop alarm audio playback if playing.
  static Future<void> stopAlarmPlayback() async {
    if (_currentAlarmPlayer == null) return;

    try {
      await _currentAlarmPlayer!.stop();
      await _currentAlarmPlayer!.dispose();
      _currentAlarmPlayer = null;
    } catch (e) {
      debugPrint('Error stopping alarm playback: $e');
      // Force null even on error to prevent repeated attempts
      _currentAlarmPlayer = null;
    }
  }
}
