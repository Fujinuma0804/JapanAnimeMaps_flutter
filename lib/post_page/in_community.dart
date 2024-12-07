import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class InCommunity extends StatefulWidget {
  final String backgroundImage;
  final String communityName;
  final String description;
  final String communityId;

  const InCommunity({
    required this.backgroundImage,
    required this.communityName,
    required this.description,
    required this.communityId,
    super.key,
  });

  @override
  State<InCommunity> createState() => _InCommunityState();
}

class _InCommunityState extends State<InCommunity> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool isLoading = false;
  File? _iconFile;

  bool get isValid => _nameController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // エラーメッセージを取得するヘルパーメソッド
  String _getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'resource-exhausted':
          return 'アクセスが集中しています。しばらく時間をおいてから再度お試しください。';
        case 'permission-denied':
          return '操作を実行する権限がありません。';
        case 'unavailable':
          return 'サービスが一時的に利用できません。ネットワーク接続を確認してください。';
        case 'unauthenticated':
          return '認証が必要です。再度ログインしてください。';
        case 'cancelled':
          return '操作がキャンセルされました。';
        case 'deadline-exceeded':
          return '操作がタイムアウトしました。ネットワーク接続を確認して再度お試しください。';
        default:
          return 'エラーが発生しました: ${error.message}';
      }
    } else if (error is Exception) {
      return 'エラーが発生しました: ${error.toString()}';
    }
    return 'エラーが発生しました。しばらく時間をおいてから再度お試しください。';
  }

  // エラーを表示するヘルパーメソッド
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '閉じる',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<String?> _uploadImage(File file, String userId) async {
    try {
      final path =
          'user_icons/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(path);

      // 画像を圧縮してアップロード
      await ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploaded_by': userId},
        ),
      );

      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      _showError(_getErrorMessage(e));
      return null;
    } catch (e) {
      _showError('画像のアップロードに失敗しました。');
      return null;
    }
  }

  Future<void> _pickAndUploadIcon() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _iconFile = File(image.path);
        });
      }
    } on Exception catch (e) {
      _showError('画像の選択中にエラーが発生しました。別の画像を試してください。');
    }
  }

  Future<void> _createProfile() async {
    if (!isValid) return;

    setState(() {
      isLoading = true;
    });

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw FirebaseAuthException(
          code: 'unauthenticated',
          message: 'ユーザーが認証されていません',
        );
      }

      String? iconUrl;
      if (_iconFile != null) {
        iconUrl = await _uploadImage(_iconFile!, currentUser.uid);
        if (iconUrl == null) {
          // 画像アップロードに失敗した場合は処理を中断
          setState(() {
            isLoading = false;
          });
          return;
        }
      }

      final userRef = _firestore.collection('users').doc(currentUser.uid);
      final communityRef =
          _firestore.collection('community_list').doc(widget.communityId);

      await _firestore.runTransaction((transaction) async {
        final communityDoc = await transaction.get(communityRef);
        if (!communityDoc.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: 'コミュニティが見つかりません',
          );
        }

        final nickname = _nameController.text.trim();

        // ユーザーのコミュニティコレクションに追加
        final userCommunityRef =
            userRef.collection('communities').doc(widget.communityId);
        transaction.set(userCommunityRef, {
          'communityName': nickname,
          'nickname': nickname,
          'iconUrl': iconUrl,
          'joinedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });

        // コミュニティのメンバーリストに追加
        final memberRef =
            communityRef.collection('add_member').doc(currentUser.uid);
        transaction.set(memberRef, {
          'nickname': nickname,
          'userId': currentUser.uid,
          'iconUrl': iconUrl,
          'isActive': true,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        // メンバー数を更新
        transaction.update(communityRef, {
          'memberCount': FieldValue.increment(1),
        });
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('コミュニティに参加しました！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseException catch (e) {
      _showError(_getErrorMessage(e));
    } catch (e) {
      _showError('プロフィールの作成に失敗しました。もう一度お試しください。');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 既存のbuildメソッドはそのまま
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.backgroundImage.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.backgroundImage,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.5),
              colorBlendMode: BlendMode.darken,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(
                  Icons.error,
                  size: 100,
                  color: Colors.grey,
                ),
              ),
            ),
          Positioned.fill(
            child: Column(
              children: [
                AppBar(
                  title: const Text(
                    'プロフィール設定',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isValid && !isLoading ? _createProfile : null,
                      child: Text(
                        '参加',
                        style: TextStyle(
                          color: isValid && !isLoading
                              ? Colors.white
                              : Colors.grey[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const SizedBox(height: 32),
                          Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                ),
                                child: _iconFile != null
                                    ? ClipOval(
                                        child: Image.file(
                                          _iconFile!,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey,
                                      ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: isLoading ? null : _pickAndUploadIcon,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isLoading
                                          ? Colors.grey
                                          : const Color(0xFF00008b),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'ニックネーム',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '必須',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              TextField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'ニックネームを入力',
                                  hintStyle: TextStyle(color: Colors.white70),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white70),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Center(
                            child: Text(
                              'このコミュニティで使用するニックネームとアイコンを\n設定できます。',
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
