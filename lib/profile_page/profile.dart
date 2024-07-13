import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? currentUser;
  DocumentSnapshot<Map<String, dynamic>>? userData;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        currentUser = user;
        userData = userDoc;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'プロフィール',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: userData == null
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 10.0),
                Stack(
                  children: [
                    Image.asset('assets/banner.jpg', fit: BoxFit.cover),
                    Positioned(
                      bottom: 0,
                      left: 16,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: const AssetImage('assets/avatar.jpg'),
                        child: IconButton(
                          icon:
                              const Icon(Icons.camera_alt, color: Colors.white),
                          onPressed: () {
                            // Add functionality to change avatar
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 16,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: () {
                          // Add functionality to change banner
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                buildProfileItem('名前', userData?.data()?['name'] ?? '未設定'),
                buildProfileItem('ID', userData?.data()?['id'] ?? '未設定'),
                buildProfileItem(
                    'メールアドレス', userData?.data()?['email'] ?? '未設定'),
                buildProfileItem('誕生日', userData?.data()?['birthday'] ?? '未設定'),
                buildProfileItem(
                    '登録日',
                    userData?.data()?['created_at']?.toDate().toString() ??
                        '未設定'),
              ],
            ),
    );
  }

  Widget buildProfileItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.black)),
          Text(value, style: const TextStyle(color: Colors.black)),
        ],
      ),
    );
  }
}
