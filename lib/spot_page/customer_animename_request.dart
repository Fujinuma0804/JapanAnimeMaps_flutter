import 'dart:typed_data';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:parts/login_page/sign_up.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'customer_anime_history.dart';

// ファイル名: customer_anime_request.dart
class AnimeNameRequestCustomerForm extends StatefulWidget {
  @override
  _AnimeNameRequestCustomerFormState createState() =>
      _AnimeNameRequestCustomerFormState();
}

class _AnimeNameRequestCustomerFormState
    extends State<AnimeNameRequestCustomerForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _animeNameController = TextEditingController();
  final TextEditingController _animeAboutController = TextEditingController();

  DateTime? _selectedDate;
  XFile? _animeImage;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isAuthorizedUser = false;

  // 通知用の変数
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
    _initializeNotifications();
  }

  void _checkUserStatus() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _isAuthorizedUser = user != null && !user.isAnonymous;
    });
  }

  // 通知を初期化するメソッド
  Future<void> _initializeNotifications() async {
    // iOS設定
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    // 初期化設定
    final InitializationSettings initializationSettings =
        InitializationSettings(
      iOS: initializationSettingsIOS,
      macOS: null,
      android: null, // Android設定は不要なのでnull
    );

    // プラグインの初期化
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 通知がタップされた時の処理
        if (response.payload != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CustomerRequestHistory()),
          );
        }
      },
    );

    // 通知の権限を明示的に要求する（iOS向け）
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  // 通知を表示するメソッド
  Future<void> _showNotification(String animeName) async {
    print('通知を表示しようとしています: $animeName'); // デバッグ用

    try {
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
      );

      NotificationDetails platformChannelSpecifics =
          NotificationDetails(iOS: iOSPlatformChannelSpecifics);

      // シミュレータ/実機で実行しているか確認
      bool isSimulator = !Platform.isIOS || false;
      print('デバイスタイプ: ${isSimulator ? "シミュレータ" : "実機"}'); // デバッグ用

      // 通知表示
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecond, // 一意のID
        'リクエスト送信完了', // タイトル
        'アニメ名「$animeName」をリクエストいただきありがとうございます。\n履歴よりステータスを確認いただけます。', // 本文
        platformChannelSpecifics,
        payload: 'history', // タップ時に渡すデータ
      );

      print('通知表示リクエスト完了'); // デバッグ用
    } catch (e) {
      print('通知表示エラー: $e'); // エラーログ
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _animeImage = image;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Color(0xFF00008b),
            colorScheme: ColorScheme.light(primary: Color(0xFF00008b)),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: Localizations.override(
            context: context,
            locale: const Locale('ja', 'JP'),
            delegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            child: child!,
          ),
        );
      },
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  void _clearForm() {
    _animeNameController.clear();
    _animeAboutController.clear();
    setState(() {
      _animeImage = null;
      _selectedDate = null;
      _agreeToTerms = false;
    });
  }

  Future<String?> _uploadImage(XFile image) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      Uint8List imageBytes = await image.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('画像の復号化に失敗しました');
      }

      img.Image resizedImage = img.copyResize(originalImage, width: 1024);
      List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 85);

      Uint8List uint8List = Uint8List.fromList(compressedBytes);

      final ref = FirebaseStorage.instance
          .ref()
          .child('anime_images/${DateTime.now().toIso8601String()}.jpg');

      final uploadTask =
          ref.putData(uint8List, SettableMetadata(contentType: 'image/jpeg'));

      // アップロード進捗状況の監視
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        setState(() {
          _uploadProgress = progress;
        });
      });

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _isUploading = false;
      });

      return downloadUrl;
    } catch (e) {
      print('画像アップロードエラー: $e');
      setState(() {
        _isUploading = false;
      });
      return null;
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate() && _agreeToTerms) {
      setState(() {
        _isLoading = true;
      });
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('ユーザーがログインしていません');

        String? animeImageUrl;

        if (_animeImage != null) {
          animeImageUrl = await _uploadImage(_animeImage!);
        }

        await FirebaseFirestore.instance
            .collection('customer_anime_request')
            .add({
          'animename': _animeNameController.text,
          'animeimage': animeImageUrl,
          'animeabout': _animeAboutController.text,
          'animedate':
              _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
          'userEmail': user.email,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'request',
        });

        _clearForm();

        // スナックバーでの通知
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('リクエストが正常に送信されました。')),
        );

        // iOSプッシュ通知を表示
        try {
          await _showNotification(_animeNameController.text);
          print('通知処理を実行しました');
        } catch (e) {
          print('通知処理中にエラーが発生しました: $e');
        }
      } catch (e) {
        print('フォーム送信エラー: $e');
        String errorMessage = '予期せぬエラーが発生しました。';
        if (e is FirebaseException) {
          errorMessage = 'Firebase エラー: ${e.message}';
        } else if (e is Exception) {
          errorMessage = 'エラー: ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('すべての必須項目を入力し、利用規約に同意してください。')),
      );
    }
  }

  void _showTermsAndPolicy() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('プライバシーポリシー\n利用規約'),
          content: SingleChildScrollView(
            child: Text(privacyPolicyText),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('閉じる'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToSignUp() {
    print('会員登録ページへ遷移');
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => SignUpPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'アニメ名リクエストフォーム',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: _isAuthorizedUser
            ? [
                IconButton(
                  icon: Icon(
                    Icons.update,
                    color: Color(0xFF00008b),
                  ),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CustomerRequestHistory()));
                  },
                ),
              ]
            : null,
      ),
      body: _isAuthorizedUser
          ? Stack(
              children: [
                Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.all(16.0),
                    children: <Widget>[
                      TextFormField(
                        controller: _animeNameController,
                        decoration: InputDecoration(labelText: 'アニメ名称'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'アニメ名称を入力してください';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 15.0),
                      TextFormField(
                        controller: _animeAboutController,
                        decoration: InputDecoration(labelText: 'アニメの概要（任意）'),
                        maxLines: 3,
                      ),
                      SizedBox(height: 15.0),
                      // 配信日選択
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: '配信日（任意）',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDate == null
                                    ? '日付を選択'
                                    : DateFormat('yyyy年MM月dd日', 'ja')
                                        .format(_selectedDate!),
                                style: TextStyle(fontSize: 16),
                              ),
                              Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20.0),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : () => _pickImage(),
                        icon: Icon(
                          _animeImage != null
                              ? Icons.check_circle
                              : Icons.add_photo_alternate,
                          color: _animeImage != null
                              ? Colors.green
                              : Color(0xFF00008b),
                        ),
                        label: Text(
                          _animeImage != null ? 'アニメ画像を変更' : 'アニメ画像をアップロード（任意）',
                          style: TextStyle(
                            color: Color(0xFF00008b),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _animeImage != null ? Colors.grey[200] : null,
                        ),
                      ),
                      if (_animeImage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Text(
                            '画像が選択されました: ${_animeImage!.name}',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _showTermsAndPolicy,
                            child: Text(
                              'プライバシーポリシーへの同意が必要です。',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: Color(0xFF00008b),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: _agreeToTerms,
                            onChanged: (bool? value) {
                              setState(() {
                                _agreeToTerms = value!;
                              });
                            },
                          ),
                          Text('同意します'),
                        ],
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _agreeToTerms && !_isLoading && !_isUploading
                            ? _submitForm
                            : null,
                        child: Text('送信'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Color(0xFF00008b),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading || _isUploading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isUploading)
                            Column(
                              children: [
                                CircularProgressIndicator(
                                  value: _uploadProgress,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  '画像アップロード中... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                              ],
                            )
                          else
                            CircularProgressIndicator(),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'このフォームを使用するにはログインが必要です。',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  ElevatedButton(
                    onPressed: _navigateToSignUp,
                    child: Text(
                      '会員登録はこちら',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Color(0xFF00008b),
                      padding: EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      textStyle: TextStyle(
                        fontSize: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                  )
                ],
              ),
            ),
    );
  }
}

const String privacyPolicyText = '''
プライバシーポリシー

1. 収集する情報
当アプリケーションは、アニメリクエストフォームの提出に際し、以下の情報を収集します：
- メールアドレス
- アニメに関する情報（アニメ名称、概要、配信日）
- アップロードされた画像

2. 情報の使用目的
収集した情報は以下の目的で使用されます：
- アニメリクエストの処理と管理
- サービスの改善と新機能の開発
- ユーザーサポートの提供

3. 情報の共有
収集した個人情報は、アニメ情報が掲載される場合にはユーザー名や画像が公開されます。
それ以外の個人情報については法律で定められた場合を除き、第三者と共有されることはありません。

4. データの保護
当アプリケーションは、収集した情報を保護するために適切なセキュリティ対策を講じています。

5. ユーザーの権利
ユーザーは自身の個人情報へのアクセス、訂正、削除を要求する権利を有しています。

6. プライバシーポリシーの変更
本プライバシーポリシーは変更される可能性があります。変更がある場合は、アプリケーション内で通知します。

7. お問い合わせ
プライバシーに関するご質問やお問い合わせは、japananimemaps@jam-info.comまでご連絡ください。

最終更新日：2024年11月7日
''';
