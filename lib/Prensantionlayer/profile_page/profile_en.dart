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
  bool isEnglish = false; // 言語設定を管理

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
        // 言語設定を取得
        isEnglish = userDoc.data()?['language'] == 'English';
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

  // 多言語対応のテキストを取得するメソッド
  String getLocalizedText(String key) {
    final texts = {
      'profile_title': isEnglish ? 'Profile' : 'プロフィール',
      'usage_days': isEnglish ? 'Usage Days' : '使用日数',
      'days_suffix': isEnglish ? ' days' : '日',
      'checkin_count': isEnglish ? 'Check-ins' : 'チェックイン数',
      'spots_suffix': isEnglish ? ' spots' : 'スポット',
      'name': isEnglish ? 'Name' : '名前',
      'id': isEnglish ? 'ID' : 'ID',
      'email': isEnglish ? 'Email' : 'Email',
      'birthday': isEnglish ? 'Birthday' : '誕生日',
      'registration_date': isEnglish ? 'Registration Date' : '登録日',
      'not_set': isEnglish ? 'Not Set' : '未設定',
    };
    return texts[key] ?? key;
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
        title: Text(
          getLocalizedText('profile_title'),
          style: const TextStyle(
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
                              ? const Icon(Icons.person, size: 60)
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
                            getLocalizedText('usage_days'),
                            '${getDaysSinceCreation()}${getLocalizedText('days_suffix')}',
                            const Color(0xFF4299E1),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatisticBox(
                            getLocalizedText('checkin_count'),
                            '${userData?.data()?['correctCount'] ?? 0}${getLocalizedText('spots_suffix')}',
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
                        _buildProfileItem(getLocalizedText('name'), userData?.data()?['name'] ?? getLocalizedText('not_set')),
                        _buildDivider(),
                        _buildProfileItem(getLocalizedText('id'), userData?.data()?['id'] ?? getLocalizedText('not_set')),
                        _buildDivider(),
                        _buildProfileItem(getLocalizedText('email'), userData?.data()?['email'] ?? getLocalizedText('not_set')),
                        _buildDivider(),
                        _buildProfileItem(getLocalizedText('birthday'), formatDate(userData?.data()?['birthday'])),
                        _buildDivider(),
                        _buildProfileItem(getLocalizedText('registration_date'), formatDate(userData?.data()?['created_at'])),
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
    if (date == null) return getLocalizedText('not_set');
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
    return getLocalizedText('not_set');
  }
}