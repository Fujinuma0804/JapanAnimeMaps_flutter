// notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:geolocator/geolocator.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    // Configure notification channels for Android
    AndroidNotificationChannel channel = const AndroidNotificationChannel(
      'location_channel',
      'Location Notifications',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    DarwinInitializationSettings iOSSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          'location_alert',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('open', 'アプリを開く'),
          ],
        ),
      ],
    );

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    InitializationSettings initSettings = InitializationSettings(
      iOS: iOSSettings,
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    // Request iOS permissions
    await _notifications
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
      critical: true,
    );

    _initialized = true;
  }

  static Future<void> _handleNotificationResponse(
      NotificationResponse response) async {
    print('Notification tapped: ${response.payload}');
    // Add navigation logic here if needed
  }

  static Future<void> showCheckInAvailableNotification(String locationName,
      String userId,
      String locationId,
      bool isCheckedIn,) async {
    try {
      if (!_initialized) await initialize();

      final String title = isCheckedIn
          ? '思い出のスポット'
          : 'チェックイン可能スポット';
      final String body = isCheckedIn
          ? '$locationNameに近づきました。以前チェックインしたスポットです。'
          : '$locationNameの近くにいます。チェックインしましょう！';

      // Store trigger in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('spot_trigger')
          .add({
        'locationId': locationId,
        'locationName': locationName,
        'timestamp': FieldValue.serverTimestamp(),
        'isCheckedIn': isCheckedIn,
        'notificationSent': true,
      });

      // Configure platform-specific notification details
      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: 'location_alert',
      );

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'location_channel',
        'Location Notifications',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        showWhen: true,
      );

      const NotificationDetails details = NotificationDetails(
        iOS: iOSDetails,
        android: androidDetails,
      );

      // Generate unique notification ID
      final int notificationId = DateTime
          .now()
          .millisecondsSinceEpoch
          .remainder(100000);

      // Show notification
      await _notifications.show(
        notificationId,
        title,
        body,
        details,
        payload: '$userId|$locationId|$isCheckedIn',
      );

      print('Notification sent: $title - $body');
    } catch (e) {
      print('Error showing notification: $e');
    }
  }
}