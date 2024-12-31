import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'admin_notices.dart';
import 'contacts_notices.dart';
import 'important_notices.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late User _user;
  late Stream<DocumentSnapshot> _userStream;
  String _userLanguage = 'English'; // デフォルト言語を日本語に設定

  @override
  void initState() {
    super.initState();
    _getUser();
    _setupUserStream();
  }

  Future<void> _getUser() async {
    _user = FirebaseAuth.instance.currentUser!;
  }

  void _setupUserStream() {
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .snapshots();

    _userStream.listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        setState(() {
          _userLanguage =
              (snapshot.data() as Map<String, dynamic>)['language'] ??
                  'English'; // デフォルトを日本語に設定
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: Text(
                _userLanguage == 'Japanese' ? 'お知らせ' : 'Notifications',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: Text(
                _userLanguage == 'Japanese' ? 'お知らせ' : 'Notifications',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF00008b),
                  ),
                ),
              ],
            ),
            body: Center(
                child: Text(_userLanguage == 'Japanese'
                    ? 'エラーが発生しました'
                    : 'An error occurred')),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: Text(
                _userLanguage == 'Japanese' ? 'お知らせ' : 'Notifications',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              bottom: TabBar(
                tabs: [
                  Tab(
                      text: _userLanguage == 'Japanese'
                          ? '重要なお知らせ'
                          : 'Important Notices'),
                  Tab(
                      text: _userLanguage == 'Japanese'
                          ? '運営より'
                          : 'Admin Notices'),
                  Tab(text: _userLanguage == 'Japanese' ? 'その他' : 'Other'),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () async {
                    openAppSettings();
                  },
                  icon: Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF00008b),
                  ),
                ),
              ],
            ),
            body: TabBarView(
              children: [
                ImportantNoticesTab(),
                AdminNoticesTab(),
                ContactUsTab(),
              ],
            ),
          ),
        );
      },
    );
  }
}
