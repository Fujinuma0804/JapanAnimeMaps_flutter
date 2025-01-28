import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ProfileEnScreen extends StatefulWidget {
  const ProfileEnScreen({Key? key}) : super(key: key);

  @override
  _ProfileEnScreenState createState() => _ProfileEnScreenState();
}

class _ProfileEnScreenState extends State<ProfileEnScreen> {
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
        TaskSnapshot snapshot = await FirebaseStorage.instance
            .ref('avatars/$fileName')
            .putFile(file);
        String downloadUrl = await snapshot.ref.getDownloadURL();

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

  int getDaysSinceCreation() {
    if (userData == null || userData!.data()?['created_at'] == null) return 0;
    final createdAt = (userData!.data()?['created_at'] as Timestamp).toDate();
    final now = DateTime.now();
    return now.difference(createdAt).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
          ' プロフィール',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          if (userData == null)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            SingleChildScrollView(
              child: Column(
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
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatisticBox(
                            '使用日数',
                            '${getDaysSinceCreation()}日',
                            const Color(0xFF4299E1),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatisticBox(
                            'チェックイン数',
                            '${userData?.data()?['correctCount'] ?? 0}スポット',
                            const Color(0xFF48BB78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildProfileItem('名前', userData?.data()?['name'] ?? '未設定'),
                        _buildDivider(),
                        _buildProfileItem('ID', userData?.data()?['id'] ?? '未設定'),
                        _buildDivider(),
                        _buildProfileItem('Email', userData?.data()?['email'] ?? '未設定'),
                        _buildDivider(),
                        _buildProfileItem('誕生日', formatDate(userData?.data()?['birthday'])),
                        _buildDivider(),
                        _buildProfileItem('登録日', formatDate(userData?.data()?['created_at'])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticBox(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2D3748),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.grey[200],
    );
  }

  String formatDate(dynamic date) {
    if (date == null) return 'Not Settings';
    if (date is Timestamp) {
      return DateFormat('yyyy.MM.dd').format(date.toDate());
    } else if (date is DateTime) {
      return DateFormat('yyyy.MM.dd').format(date);
    } else if (date is String) {
      try {
        return DateFormat('yyyy.MM.dd').format(DateTime.parse(date));
      } catch (e) {
        return date;
      }
    }
    return 'Not Settings';
  }
}