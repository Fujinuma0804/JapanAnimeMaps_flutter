import 'package:flutter/material.dart';
import 'package:parts/login_page/welcome_page/welcome_3.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Welcome2 extends StatefulWidget {
  @override
  _Welcome2State createState() => _Welcome2State();
}

class _Welcome2State extends State<Welcome2> {
  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  void _checkFirstTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (isFirstTime) {
      prefs.setBool('isFirstTime', false);
      _requestNotificationPermissions(firstTime: true);
    } else {
      _requestNotificationPermissions(firstTime: false);
    }
  }

  Future<void> _requestNotificationPermissions(
      {required bool firstTime}) async {
    PermissionStatus status = await Permission.notification.status;
    print("Initial status: $status");

    if (status.isGranted) {
      print("Notification permissions already granted");
      _navigateToWelcome3();
    } else if (status.isDenied || status.isRestricted) {
      if (firstTime) {
        // Use the reference function to request permission
        await requestNotificationPermission(); // Now this is valid
        status = await Permission.notification.status; // Check the status again
        if (status.isGranted) {
          print("Notification permissions granted");
          _navigateToWelcome3();
        } else if (status.isPermanentlyDenied) {
          print("Notification permissions permanently denied");
          openAppSettings();
        } else {
          print("Notification permissions denied");
        }
      } else {
        print("Opening app settings");
        openAppSettings();
      }
    } else if (status.isPermanentlyDenied) {
      print("Notification permissions permanently denied");
      openAppSettings();
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
              '欲しい情報をプッシュ通知で受け取ろう',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'お得な情報や商品の注文状況など、欲しい情報だけを受け取れます。',
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
                      onPressed: () {
                        _requestNotificationPermissions(firstTime: true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0B3D91),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: Text(
                        '許可',
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
                        'スキップ',
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
