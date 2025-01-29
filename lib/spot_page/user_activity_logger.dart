// user_activity_logger.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class UserActivityLogger {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.reference();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // デバイス情報を取得
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return {
          'platform': 'Android',
          'model': androidInfo.model,
          'version': androidInfo.version.release,
          'manufacturer': androidInfo.manufacturer,
        };
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return {
          'platform': 'iOS',
          'model': iosInfo.model,
          'version': iosInfo.systemVersion,
        };
      }
    } catch (e) {
      print('Error getting device info: $e');
    }
    return {'platform': 'Unknown'};
  }

  // アプリバージョンを取得
  Future<String> _getAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      print('Error getting app version: $e');
      return 'unknown';
    }
  }

  // ユーザーアクティビティを記録
  Future<void> logUserActivity(String activity, Map<String, dynamic> data) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final appVersion = await _getAppVersion();
      final timestamp = DateTime.now();

      await _firestore.collection('user_activities').add({
        'activity': activity,
        'data': data,
        'deviceInfo': deviceInfo,
        'appVersion': appVersion,
        'timestamp': timestamp,
        'sessionId': _generateSessionId(),
      });
    } catch (e) {
      print('Error logging user activity: $e');
    }
  }

  String _generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}