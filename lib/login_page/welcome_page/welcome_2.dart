import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'welcome_3.dart'; // Update import based on your directory structure

class Welcome2 extends StatefulWidget {
  @override
  _Welcome2State createState() => _Welcome2State();
}

class _Welcome2State extends State<Welcome2> {
  String _notificationText = '欲しい情報をプッシュ通知で受け取ろう'; // Default to Japanese text

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
    _getUserLanguage();
  }

  void _checkFirstTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (isFirstTime) {
      prefs.setBool('isFirstTime', false);
    }
  }

  Future<void> _getUserLanguage() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        String language =
            (userDoc.data() as Map<String, dynamic>)['language'] ?? 'English';
        setState(() {
          _notificationText = language == 'Japanese'
              ? '欲しい情報をプッシュ通知で受け取ろう'
              : 'Receive desired information via push notifications';
        });
      }
    }
  }

  Future<void> _requestNotificationPermissions() async {
    final messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('FCM permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("FCM Notification permissions granted");
      _navigateToWelcome3();
    } else {
      PermissionStatus status = await Permission.notification.status;
      print("Initial permission_handler status: $status");

      if (status.isGranted) {
        print("Notification permissions already granted");
        _navigateToWelcome3();
      } else if (status.isDenied) {
        await requestNotificationPermission();
        status = await Permission.notification.status;
        if (status.isGranted) {
          print("Notification permissions granted");
          _navigateToWelcome3();
        } else if (status.isPermanentlyDenied) {
          print("Notification permissions permanently denied");
          openAppSettings();
        } else {
          print("Notification permissions denied");
        }
      } else if (status.isPermanentlyDenied) {
        print("Notification permissions permanently denied");
        openAppSettings();
      }
    }
  }

  Future<void> requestNotificationPermission() async {
    PermissionStatus permissionStatus = await Permission.notification.status;
    if (permissionStatus.isDenied) {
      await Permission.notification.request();
    }
  }

  void _navigateToWelcome3() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Welcome3()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            SizedBox(height: 40),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            Spacer(),
            Image.asset(
              'assets/images/Welcome-notification.png',
              height: 200,
            ),
            SizedBox(height: 40),
            Text(
              _notificationText,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              _notificationText == '欲しい情報をプッシュ通知で受け取ろう'
                  ? 'お得な情報や商品の注文状況など、欲しい情報だけを受け取れます。'
                  : 'Receive only the information you want, such as special offers and order status.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            Spacer(),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _requestNotificationPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0B3D91),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: Text(
                        _notificationText == '欲しい情報をプッシュ通知で受け取ろう'
                            ? '許可'
                            : 'Allow',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: OutlinedButton(
                      onPressed: _navigateToWelcome3,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        side: BorderSide(color: Colors.black),
                      ),
                      child: Text(
                        _notificationText == '欲しい情報をプッシュ通知で受け取ろう'
                            ? 'スキップ'
                            : 'Skip',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
