import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditProfilePage extends StatefulWidget {
  final String currentName;
  final String currentBio;
  final String currentLocation;
  final String currentWebsite;
  final String currentFavoriteAnime;

  const EditProfilePage({
    Key? key,
    required this.currentName,
    required this.currentBio,
    required this.currentLocation,
    required this.currentWebsite,
    required this.currentFavoriteAnime,
  }) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _websiteController;
  late TextEditingController _favoriteAnimeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _bioController = TextEditingController(text: widget.currentBio);
    _locationController = TextEditingController(text: widget.currentLocation);
    _websiteController = TextEditingController(text: widget.currentWebsite);
    _favoriteAnimeController =
        TextEditingController(text: widget.currentFavoriteAnime);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    _favoriteAnimeController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_auth.currentUser == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // プロフィールデータを準備
      final profileData = {
        'name': _nameController.text,
        'bio': _bioController.text,
        'location': _locationController.text,
        'website': _websiteController.text,
        'favoriteAnime': _favoriteAnimeController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Firebaseのユーザードキュメントを更新
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update(profileData);

      // 更新されたデータを前の画面に返す
      Navigator.pop(context, profileData);
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('プロフィールの更新に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'プロフィールを編集',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          _isSaving
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveProfile,
                  child: Text(
                    '保存',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderImage(),
            _buildProfileImage(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: '名前',
                    maxLength: 50,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _bioController,
                    label: '自己紹介',
                    maxLength: 160,
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _locationController,
                    label: '場所',
                    maxLength: 30,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _websiteController,
                    label: 'ウェブサイト',
                    maxLength: 100,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    controller: _favoriteAnimeController,
                    label: '好きなアニメ',
                    maxLength: 50,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderImage() {
    return Container(
      height: 150,
      width: double.infinity,
      color: Colors.grey[200],
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.camera_alt,
              size: 32,
              color: Colors.grey[600],
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Transform.translate(
      offset: Offset(0, -40),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.camera_alt,
                size: 24,
                color: Colors.grey[600],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required int maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
      ),
    );
  }
}
