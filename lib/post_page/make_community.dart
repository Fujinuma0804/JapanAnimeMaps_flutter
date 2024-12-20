import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parts/post_page/post_first/community_chat.dart';
import 'package:path/path.dart' as path;

// 広告ヘルパークラス
class AdHelper {
  // プラットフォームに応じたテスト用広告IDを返す
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Androidのテスト用ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411151342'; // iOSのテスト用ID
    } else {
      throw UnsupportedError('対応していないプラットフォームです');
    }
  }

  // 広告SDKの初期化
  static Future<void> initializeAds() async {
    await MobileAds.instance.initialize();
  }
}

// 広告管理クラス
class AdManager {
  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;

  // インタースティシャル広告のロード
  Future<void> loadInterstitialAd({
    required Function() onAdDismissed, // 広告が閉じられた時のコールバック
    required Function(String) onError, // エラー発生時のコールバック
  }) async {
    if (_isAdLoading || _interstitialAd != null) return;

    _isAdLoading = true;

    try {
      await InterstitialAd.load(
        adUnitId: AdHelper.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isAdLoading = false;

            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _interstitialAd = null;
                onAdDismissed();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _interstitialAd = null;
                onError('広告の表示に失敗しました: ${error.message}');
                onAdDismissed(); // エラーが発生しても次の画面に進む
              },
            );
          },
          onAdFailedToLoad: (error) {
            _isAdLoading = false;
            onError('広告の読み込みに失敗しました: ${error.message}');
            onAdDismissed(); // エラーが発生しても次の画面に進む
          },
        ),
      );
    } catch (e) {
      _isAdLoading = false;
      onError('広告読み込み中に例外が発生しました: $e');
      onAdDismissed(); // エラーが発生しても次の画面に進む
    }
  }

  // 広告の表示
  Future<void> showInterstitialAd() async {
    if (_interstitialAd == null) return;

    try {
      await _interstitialAd!.show();
    } catch (e) {
      _interstitialAd?.dispose();
      _interstitialAd = null;
    }
  }

  // リソースの解放
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}

// CategoryModel class
class CategoryModel {
  final String id;
  final String name;

  CategoryModel({
    required this.id,
    required this.name,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// OpenChatProfileScreen
class OpenChatProfileScreen extends StatefulWidget {
  final String backgroundImage;
  final String communityName;
  final String description;
  final String hashtag;
  final List<CategoryModel> selectedCategories;

  const OpenChatProfileScreen({
    required this.backgroundImage,
    required this.communityName,
    required this.description,
    required this.hashtag,
    required this.selectedCategories,
    super.key,
  });

  @override
  State<OpenChatProfileScreen> createState() => _OpenChatProfileScreenState();
}

class _OpenChatProfileScreenState extends State<OpenChatProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool isLoading = false;
  bool isAgreedToTerms = false;
  File? _iconFile;

  bool get isValid => _nameController.text.trim().isNotEmpty && isAgreedToTerms;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadIcon() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _iconFile = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の選択中にエラーが発生しました: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImageToFirebase(File file, String folderPath) async {
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final Reference storageRef =
          FirebaseStorage.instance.ref().child('$folderPath/$fileName');

      final UploadTask uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploaded_by': 'app_user'},
        ),
      );

      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('画像のアップロードに失敗: $e');
      return null;
    }
  }

  Future<void> _createCommunity() async {
    if (!isValid) return;

    setState(() {
      isLoading = true;
    });

    try {
      String? iconImageUrl;
      String? backgroundImageUrl;

      if (_iconFile != null) {
        iconImageUrl =
            await _uploadImageToFirebase(_iconFile!, 'community_icons');
      }

      if (widget.backgroundImage.isNotEmpty) {
        final backgroundFile = File(widget.backgroundImage);
        backgroundImageUrl = await _uploadImageToFirebase(
            backgroundFile, 'community_backgrounds');
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('ユーザーが見つかりません');
      }

      // コミュニティのメインドキュメントを作成
      final communityRef =
          await FirebaseFirestore.instance.collection('community_list').add({
        'name': widget.communityName,
        'displayName': _nameController.text.trim(),
        'description': widget.description,
        'hashtag': widget.hashtag,
        'categories': widget.selectedCategories.map((c) => c.id).toList(),
        'iconUrl': iconImageUrl,
        'backgroundImageUrl': backgroundImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updateAt': FieldValue.serverTimestamp(),
        'memberCount': 1,
        'isActive': true,
      });

      // Firestoreのバッチ処理を作成
      final batch = FirebaseFirestore.instance.batch();

      // ユーザーのコミュニティ参加情報を追加
      final userCommunityRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('communities')
          .doc(communityRef.id);

      batch.set(userCommunityRef, {
        'communityName': widget.communityName,
        'iconUrl': iconImageUrl,
        'isActive': true,
        'joinedAt': FieldValue.serverTimestamp(),
        'nickname': _nameController.text.trim(),
        'authority': 'admin',
      });

      // コミュニティのadd_memberサブコレクションにadminユーザーを追加
      final addMemberRef =
          communityRef.collection('add_member').doc(currentUser.uid);

      batch.set(addMemberRef, {
        'uid': currentUser.uid,
        'nickname': _nameController.text.trim(),
        'iconUrl': iconImageUrl,
        'authority': 'admin',
        'isActive': true,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // バッチ処理を実行
      await batch.commit();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatScreen(
              roomName: widget.communityName,
              communityId: communityRef.id,
              participantCount: 1,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('コミュニティの作成に失敗しました: $e')),
        );
      }
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
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.backgroundImage.isNotEmpty)
            Image.file(
              File(widget.backgroundImage),
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.5),
              colorBlendMode: BlendMode.darken,
            ),
          Positioned.fill(
            child: Column(
              children: [
                AppBar(
                  title: const Text(
                    'コミュニティのプロフィール設定',
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
                      onPressed:
                          isValid && !isLoading ? _createCommunity : null,
                      child: Text(
                        '完了',
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
                                        horizontal: 8, vertical: 2),
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
                              'このコミュニティで使用するニックネームとアイコンを\n'
                              '設定できます。メールアドレスなどは公開されません。',
                              style: TextStyle(
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Checkbox(
                                value: isAgreedToTerms,
                                onChanged: (value) {
                                  setState(() {
                                    isAgreedToTerms = value ?? false;
                                  });
                                },
                                fillColor: MaterialStateProperty.resolveWith(
                                  (states) =>
                                      states.contains(MaterialState.selected)
                                          ? const Color(0xFF00008b)
                                          : Colors.white,
                                ),
                                checkColor: Colors.white,
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    const Text(
                                      '利用規約に同意します',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '必須',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

// CreateOpenChatScreen
class CreateOpenChatScreen extends StatefulWidget {
  const CreateOpenChatScreen({super.key});

  @override
  State<CreateOpenChatScreen> createState() => _CreateOpenChatScreenState();
}

class _CreateOpenChatScreenState extends State<CreateOpenChatScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<CategoryModel> _categories = [];
  Set<CategoryModel> _selectedCategories = {};
  bool _isLoading = true;
  String? _error;
  File? _imageFile;
  bool _isNameValid = false;
  InterstitialAd? _interstitialAd;

  // テスト用広告ID
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712' // Androidのテスト用ID
      : 'ca-app-pub-3940256099942544/4411151342'; // iOSのテスト用ID

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _nameController.addListener(_validateName);
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('インタースティシャル広告のロード成功');
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('広告が閉じられました');
              _navigateToNext();
              ad.dispose();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('広告の表示に失敗しました: $error');
              ad.dispose();
              _navigateToNext();
            },
            onAdShowedFullScreenContent: (ad) {
              debugPrint('広告が表示されました');
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('インタースティシャル広告の読み込みに失敗: $error');
          _interstitialAd = null;
          // 広告の読み込みに失敗した場合は、一定時間後に再試行
          Future.delayed(const Duration(minutes: 1), _loadInterstitialAd);
        },
      ),
    );
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _nameController.removeListener(_validateName);
    _nameController.dispose();
    _descriptionController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  void _validateName() {
    setState(() {
      _isNameValid = _nameController.text.trim().isNotEmpty;
    });
  }

  bool _hasContent() {
    return _nameController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty ||
        _hashtagController.text.isNotEmpty ||
        _imageFile != null ||
        _selectedCategories.isNotEmpty;
  }

  void _showCloseConfirmationDialog() {
    if (_hasContent()) {
      showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              content: const Text(
                'この画面を閉じると、\n'
                'コミュニティは作成\n'
                'されずに、編集内容は破棄\n'
                'されます。画面を閉じますか？',
              ),
              actions: [
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    '閉じる',
                    style: TextStyle(
                      color: Colors.blue,
                    ),
                  ),
                ),
                CupertinoDialogAction(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'キャンセル',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像の選択中にエラーが発生しました: $e')),
      );
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('category_community')
          .get();

      final categories =
          snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();

      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleCategory(CategoryModel category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        if (_selectedCategories.length < 3) {
          _selectedCategories.add(category);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('カテゴリーは最大3つまで選択できます')),
          );
        }
      }
    });
  }

  void _showAdAndNavigate() {
    if (_isNameValid) {
      if (_interstitialAd != null) {
        _interstitialAd!.show().catchError((error) {
          debugPrint('広告表示中にエラーが発生: $error');
          _navigateToNext(); // エラー時は直接画面遷移
        });
      } else {
        debugPrint('広告がロードされていないため、直接画面遷移します');
        _loadInterstitialAd(); // 次回のために再ロード
        _navigateToNext();
      }
    }
  }

  void _navigateToNext() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OpenChatProfileScreen(
          backgroundImage: _imageFile?.path ?? '',
          communityName: _nameController.text,
          description: _descriptionController.text,
          hashtag: _hashtagController.text,
          selectedCategories: _selectedCategories.toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(CategoryModel category) {
    final isSelected = _selectedCategories.contains(category);
    return GestureDetector(
      onTap: () => _toggleCategory(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00008b) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF00008b) : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.close,
            color: Color(0xFF00008b),
          ),
          onPressed: _showCloseConfirmationDialog,
        ),
        title: const Text(
          'コミュニティを作成',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isNameValid ? _showAdAndNavigate : null,
            child: Text(
              '次へ',
              style: TextStyle(
                color: _isNameValid ? const Color(0xFF00008b) : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: _imageFile != null
                      ? DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _imageFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'この画像はコミュニティのプロフィールおよび\nアイコンの背景に適用されます。',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            icon: const Icon(Icons.camera_alt),
                            onPressed: _pickImage,
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Text(
                  'コミュニティの名前を入力',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  '  入力必須',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'コミュニティの名前を入力',
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                suffixText: '${_nameController.text.length} / 50',
                errorText: !_isNameValid && _nameController.text.isNotEmpty
                    ? 'コミュニティ名を入力してください'
                    : null,
              ),
              maxLength: 50,
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              onChanged: (text) => setState(() {}),
            ),
            const SizedBox(height: 24),
            const Text('説明', style: TextStyle(fontSize: 14)),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: '説明を入力',
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                suffixText: '${_descriptionController.text.length} / 1000',
              ),
              maxLength: 1000,
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              onChanged: (text) => setState(() {}),
              maxLines: null,
            ),
            const SizedBox(height: 24),
            const Text('「#」から始まるハッシュタグを入力', style: TextStyle(fontSize: 14)),
            TextField(
              controller: _hashtagController,
              decoration: InputDecoration(
                hintText: '#ハッシュタグ',
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('カテゴリー', style: TextStyle(fontSize: 14)),
            const Text(
              'カテゴリーを設定すると、ユーザーが検索した時にこのコミュニティが見つかりやすくなります。\n最大3つまで選択できます。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(child: Text('エラーが発生しました: $_error'))
            else if (_categories.isEmpty)
              const Center(child: Text('カテゴリーがありません'))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories
                    .map((category) => _buildCategoryChip(category))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
