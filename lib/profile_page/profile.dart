import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? currentUser;
  DocumentSnapshot<Map<String, dynamic>>? userData;
  String? avatarUrl;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    setState(() {
      isLoading = true;
    });

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
        avatarUrl = userDoc.data()?['avatarUrl'];
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> changeAvatar() async {
    setState(() {
      isLoading = true;
    });

    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      File file = File(image.path);
      String fileName = '${currentUser!.uid}_avatar.jpg';

      try {
        // Upload image to Firebase Storage
        TaskSnapshot snapshot = await FirebaseStorage.instance
            .ref('avatars/$fileName')
            .putFile(file);

        // Get download URL
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // Update Firestore document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .update({'avatarUrl': downloadUrl});

        setState(() {
          avatarUrl = downloadUrl;
          isLoading = false;
        });
      } catch (e) {
        print('Error uploading avatar: $e');
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatDate(dynamic date) {
    if (date == null) return '未設定';
    if (date is Timestamp) {
      return DateFormat('yyyy年MM月dd日').format(date.toDate());
    } else if (date is DateTime) {
      return DateFormat('yyyy年MM月dd日').format(date);
    } else if (date is String) {
      try {
        return DateFormat('yyyy年MM月dd日').format(DateTime.parse(date));
      } catch (e) {
        return date;
      }
    }
    return '未設定';
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
      body: Stack(
        children: [
          if (userData == null)
            Center(child: CircularProgressIndicator())
          else
            Column(
              children: [
                const SizedBox(height: 20.0),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                        child: avatarUrl == null
                            ? Icon(Icons.person, size: 60)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: IconButton(
                          icon:
                              const Icon(Icons.camera_alt, color: Colors.blue),
                          onPressed: changeAvatar,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                buildProfileItem('名前', userData?.data()?['name'] ?? '未設定'),
                buildProfileItem('ID', userData?.data()?['id'] ?? '未設定'),
                buildProfileItem(
                    'メールアドレス', userData?.data()?['email'] ?? '未設定'),
                buildProfileItem(
                    '誕生日', formatDate(userData?.data()?['birthday'])),
                buildProfileItem(
                    '登録日', formatDate(userData?.data()?['created_at'])),
              ],
            ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
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
