import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PostScreen extends StatefulWidget {
  final String locationId;
  final String userId;

  const PostScreen({Key? key, required this.locationId, required this.userId})
      : super(key: key);

  @override
  _PostScreenState createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  File? _image;
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;
  bool _hasCheckedIn = false;
  String _userDisplayName = '';
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _checkUserCheckedIn();
    _getUserDisplayName();
    _getUserInfo();
  }

  Future<void> _getUserInfo() async {
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    setState(() {
      _userDisplayName = userSnapshot['name'] ?? 'Unknown';
      _userId = userSnapshot['id'] ?? widget.userId;
    });
  }

  Future<void> _checkUserCheckedIn() async {
    QuerySnapshot checkInSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('check_ins')
        .where('locationId', isEqualTo: widget.locationId)
        .limit(1)
        .get();

    setState(() {
      _hasCheckedIn = checkInSnapshot.docs.isNotEmpty;
    });
  }

  Future<void> _getUserDisplayName() async {
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    setState(() {
      _userDisplayName = userSnapshot['displayName'] ?? widget.userId;
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _image = File(image.path);
      });
    }
  }

  Future<void> _sharePost() async {
    if (!_hasCheckedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この場所でチェックインしていません')),
      );
      return;
    }

    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像を選択してください')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // 画像をFirebase Storageにアップロード
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('location_images')
          .child(widget.locationId)
          .child(fileName);

      await ref.putFile(_image!);
      String downloadURL = await ref.getDownloadURL();

      // Firestoreに投稿情報を保存
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.locationId)
          .collection('posts')
          .add({
        'imageUrl': downloadURL,
        'caption': _captionController.text,
        'userId': widget.userId,
        'userDisplayName': _userDisplayName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿が完了しました')),
      );

      Navigator.pop(context); // 投稿画面を閉じる
    } catch (e) {
      print('Error sharing post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿に失敗しました')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '新規投稿',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('投稿するユーザ: @$_userId'),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                ),
                child: _image == null
                    ? const Icon(Icons.add_a_photo, size: 50)
                    : Image.file(_image!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                hintText: 'キャプションを入力してください',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isUploading || !_hasCheckedIn ? null : _sharePost,
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : Text(_hasCheckedIn ? 'シェア' : 'チェックインが必要です'),
            ),
          ],
        ),
      ),
    );
  }
}
