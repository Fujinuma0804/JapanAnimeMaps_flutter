import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  final String currentName;
  final String currentBio;
  final String currentLocation;
  final String currentWebsite;
  final String currentFavoriteAnime;
  final String? currentHeaderImageUrl;
  final String? currentAvatarUrl;

  const EditProfilePage({
    Key? key,
    required this.currentName,
    required this.currentBio,
    required this.currentLocation,
    required this.currentWebsite,
    required this.currentFavoriteAnime,
    this.currentHeaderImageUrl,
    this.currentAvatarUrl,
  }) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSaving = false;
  File? _headerImageFile;
  File? _avatarFile;
  String? _headerImageUrl;
  String? _avatarUrl;

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
    _headerImageUrl = widget.currentHeaderImageUrl;
    _avatarUrl = widget.currentAvatarUrl;
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

  Future<void> _pickHeaderImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _headerImageFile = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking header image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('画像の選択に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _avatarFile = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking avatar image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('画像の選択に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _uploadImage(
      File? imageFile, String? currentUrl, String folder) async {
    if (imageFile == null) return currentUrl;

    try {
      final String fileName =
          '${folder}/${_auth.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child(fileName);

      // 既存の画像がある場合は削除
      if (currentUrl != null) {
        try {
          await _storage.refFromURL(currentUrl).delete();
        } catch (e) {
          print('Error deleting old image: $e');
        }
      }

      // 新しい画像をアップロード
      await ref.putFile(imageFile);
      final String downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }

  Future<void> _saveProfile() async {
    if (_auth.currentUser == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // 画像をアップロード
      final String? headerImageUrl = await _uploadImage(
          _headerImageFile, _headerImageUrl, 'header_images');
      final String? avatarUrl =
          await _uploadImage(_avatarFile, _avatarUrl, 'avatars');

      // プロフィールデータを準備
      final profileData = {
        'name': _nameController.text,
        'bio': _bioController.text,
        'location': _locationController.text,
        'website': _websiteController.text,
        'favoriteAnime': _favoriteAnimeController.text,
        'headerImageUrl': headerImageUrl,
        'avatarUrl': avatarUrl,
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
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'プロフィールを編集',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveProfile,
                  child: Text(
                    '保存',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderSection(),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('基本情報'),
                    _buildTextField(
                      controller: _nameController,
                      label: '名前',
                      maxLength: 50,
                      icon: Icons.person_outline,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _bioController,
                      label: '自己紹介',
                      maxLength: 160,
                      maxLines: 3,
                      icon: Icons.description_outlined,
                    ),
                    SizedBox(height: 24),
                    _buildSectionTitle('詳細情報'),
                    _buildTextField(
                      controller: _locationController,
                      label: '場所',
                      maxLength: 30,
                      icon: Icons.location_on_outlined,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _websiteController,
                      label: 'ウェブサイト',
                      maxLength: 100,
                      icon: Icons.link,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _favoriteAnimeController,
                      label: '好きなアニメ',
                      maxLength: 50,
                      icon: Icons.favorite_border,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        _buildHeaderImage(),
        Positioned(
          bottom: -40,
          child: _buildAvatar(),
        ),
        SizedBox(height: 40), // アバター画像の下部スペース確保
      ],
    );
  }

  Widget _buildHeaderImage() {
    return GestureDetector(
      onTap: _pickHeaderImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          image: _headerImageFile != null
              ? DecorationImage(
                  image: FileImage(_headerImageFile!),
                  fit: BoxFit.cover,
                )
              : widget.currentHeaderImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(widget.currentHeaderImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.4),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt,
                size: 32,
                color: Colors.white,
              ),
              SizedBox(height: 8),
              Text(
                'カバー画像を変更',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _pickAvatar,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
          image: _avatarFile != null
              ? DecorationImage(
                  image: FileImage(_avatarFile!),
                  fit: BoxFit.cover,
                )
              : widget.currentAvatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(widget.currentAvatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
        ),
        child: _avatarFile == null && widget.currentAvatarUrl == null
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt,
                      size: 24,
                      color: Colors.grey[600],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '写真を追加',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0),
                      Colors.black.withOpacity(0.5),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white.withOpacity(0.8),
                  size: 24,
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required int maxLength,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.grey[600]),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          border: InputBorder.none,
          counterText: '',
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
        style: TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
    );
  }
}
