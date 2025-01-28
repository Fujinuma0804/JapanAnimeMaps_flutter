// background_location.dart
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:parts/map_page/notification_service.dart';

class LocationService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        foregroundServiceNotificationId: 888,
        initialNotificationContent: 'バックグラウンドで位置情報を取得しています',
        initialNotificationTitle: 'バックグラウンド実行中',
      ),
    );

    try {
      await _requestLocationPermission();
      await _startLocationTracking();
      await service.startService();
    } catch (e) {
      print('Error initializing location service: $e');
    }
  }

  static Future<bool> onIosBackground(ServiceInstance service) async {
    await _handleLocationUpdate();
    return true;
  }

  static void onStart(ServiceInstance service) async {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      timeLimit: const Duration(seconds: 5),
    );

    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      try {
        await _handleLocationUpdate();
      } catch (e) {
        print('Error in position stream: $e');
      }
    }, onError: (error) {
      print('Error in location stream: $error');
    }, cancelOnError: false);
  }

  static Future<void> _handleLocationUpdate() async {
    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final locations = await FirebaseFirestore.instance
          .collection('locations')
          .limit(50)
          .get();

      for (var doc in locations.docs) {
        await _processLocation(doc, currentPosition, currentUser.uid);
      }
    } catch (e) {
      print('Error handling location update: $e');
    }
  }

  static Future<void> _processLocation(
      QueryDocumentSnapshot doc,
      Position currentPosition,
      String userId,
      ) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final locationLat = data['latitude'] as double;
      final locationLng = data['longitude'] as double;

      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        locationLat,
        locationLng,
      );

      if (distance <= 500) {
        final checkInDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('check_ins')
            .where('locationId', isEqualTo: doc.id)
            .get();

        await NotificationService.showCheckInAvailableNotification(
          data['title'],
          userId,
          doc.id,
          checkInDoc.docs.isNotEmpty,
        );
      }
    } catch (e) {
      print('Error processing location: $e');
    }
  }

  static Future<void> _startLocationTracking() async {
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position? position) {
      if (position != null) {
        print('Location Update: ${position.latitude}, ${position.longitude}');
      }
    });
  }

  static Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }
  }
}