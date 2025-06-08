import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'qa_form_thanks.dart';

class QAFormPage extends StatefulWidget {
  final String? initialGenre;

  const QAFormPage({Key? key, this.initialGenre}) : super(key: key);

  @override
  State<QAFormPage> createState() => _QAFormPageState();
}

class _QAFormPageState extends State<QAFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isAgreed = false;
  bool _isLoading = false;
  String _loadingMessage = '送信中...';

  String? _userEmail;
  String? _userId;
  String? _genre;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  // ユーザー情報を初期化
  Future<void> _initializeUserData() async {
    print('🔄 Initializing user data...');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('✅ User logged in: ${user.email}');
        setState(() {
          _userEmail = user.email ?? '';
          _userId = user.uid;
          _genre = widget.initialGenre ?? 'その他';
        });
      } else {
        print('⚠️ No user logged in, using guest mode');
        setState(() {
          _userEmail = 'ゲストユーザー';
          _userId = 'guest_user';
          _genre = widget.initialGenre ?? 'その他';
        });
      }
      print('✅ User data initialized: Email=$_userEmail, Genre=$_genre');
    } catch (e) {
      print('❌ Error initializing user data: $e');
      setState(() {
        _userEmail = 'ゲストユーザー';
        _userId = 'guest_user';
        _genre = widget.initialGenre ?? 'その他';
      });
    }
  }

  // 管理番号を生成
  String _generateManagementNumber() {
    final now = DateTime.now();
    final dateString = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = Random();
    final randomString = List.generate(8, (index) =>
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'[random.nextInt(62)]
    ).join();
    final managementNumber = '$dateString-$randomString';
    print('📋 Generated management number: $managementNumber');
    return managementNumber;
  }

  // フォームを送信
  Future<void> _submitForm() async {
    print('📤 Starting form submission...');

    if (!_formKey.currentState!.validate() || !_isAgreed) {
      if (!_isAgreed) {
        print('❌ Privacy policy not agreed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プライバシーポリシーに同意してください'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'データを準備中...';
    });

    try {
      final managementNumber = _generateManagementNumber();
      final now = DateTime.now();

      print('💾 Saving to Firestore...');
      setState(() {
        _loadingMessage = 'データを保存中...';
      });

      // Firestoreにデータを保存（タイムアウト設定）
      final docRef = await FirebaseFirestore.instance
          .collection('inquiries')
          .add({
        'managementNumber': managementNumber,
        'userEmail': _userEmail,
        'userId': _userId,
        'genre': _genre,
        'name': _nameController.text.trim(),
        'content': _contentController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'createdAt': Timestamp.fromDate(now),
        'status': 'pending',
      }).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Firestore保存がタイムアウトしました');
        },
      );

      print('✅ Firestore save successful: ${docRef.id}');

      // メール送信リクエストをバックグラウンドで実行
      setState(() {
        _loadingMessage = 'メール送信リクエストを作成中...';
      });

      _sendEmailRequestInBackground(managementNumber, docRef.id);

      print('🎯 Navigating to thanks page...');

      // 完了画面へ遷移（メール送信を待たない）
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QAFormThanksPage(
              managementNumber: managementNumber,
              inquiryData: {
                'name': _nameController.text.trim(),
                'email': _userEmail!,
                'genre': _genre!,
                'content': _contentController.text.trim(),
                'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error submitting form: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '送信中...';
        });

        String errorMessage = '送信に失敗しました。もう一度お試しください。';
        if (e.toString().contains('timeout') || e.toString().contains('タイムアウト')) {
          errorMessage = 'ネットワークの応答が遅いため、送信に失敗しました。しばらく時間をおいてからお試しください。';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // メール送信リクエストをバックグラウンドで実行
  void _sendEmailRequestInBackground(String managementNumber, String docId) async {
    try {
      print('📧 Starting background email request...');
      print('📧 Management Number: $managementNumber');
      print('📧 Document ID: $docId');
      print('📧 User Email: $_userEmail');
      print('📧 User ID: $_userId');
      print('📧 Genre: $_genre');
      print('📧 Current Time: ${DateTime.now()}');

      await _createEmailRequest(managementNumber, docId);
      print('✅ Background email request completed');
    } catch (e) {
      print('⚠️ Background email request failed: $e');
      print('⚠️ Error type: ${e.runtimeType}');
      print('⚠️ Stack trace: ${StackTrace.current}');

      // メール送信リクエスト失敗をFirestoreにログとして記録
      try {
        await FirebaseFirestore.instance
            .collection('email_logs')
            .add({
          'managementNumber': managementNumber,
          'docId': docId,
          'userEmail': _userEmail,
          'error': e.toString(),
          'errorType': e.runtimeType.toString(),
          'timestamp': Timestamp.now(),
          'status': 'failed_background',
        });
        print('📝 Email request failure logged to Firestore');
      } catch (logError) {
        print('❌ Failed to log email request error: $logError');
      }
    }
  }

  // メール送信リクエストを作成（Firebase Functions経由）
  Future<void> _createEmailRequest(String managementNumber, String docId) async {
    try {
      print('📧 ===== EMAIL REQUEST START (Firebase Functions) =====');
      print('📧 Management Number: $managementNumber');
      print('📧 Document ID: $docId');
      print('📧 Current DateTime: ${DateTime.now()}');

      // メール送信リクエストをFirestoreに保存
      print('📧 Creating email request in Firestore...');

      await FirebaseFirestore.instance
          .collection('email_requests')
          .add({
        'managementNumber': managementNumber,
        'docId': docId,
        'userEmail': _userEmail,
        'userName': _nameController.text.trim(),
        'adminEmail': 'sota@jam-info.com',
        'fromEmail': 'noreply-contactform@animetourism.co.jp',
        'genre': _genre,
        'content': _contentController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'userId': _userId,
        'timestamp': Timestamp.now(),
        'status': 'pending',
        'type': 'contact_form',

        // ユーザー向けメールの内容
        'userEmailSubject': '【JapanAnimeMaps】お問い合わせを受け付けました',
        'userEmailBody': '''
${_nameController.text.trim()} 様

この度は、JapanAnimeMapsにお問い合わせいただき、ありがとうございます。
以下の内容でお問い合わせを受け付けいたしました。

管理番号: $managementNumber
お名前: ${_nameController.text.trim()}
メールアドレス: $_userEmail
ジャンル: $_genre
お問い合わせ内容:
${_contentController.text.trim()}
${_phoneController.text.trim().isNotEmpty ? '\nお電話番号: ${_phoneController.text.trim()}' : ''}

通常3営業日以内にご返答いたします。
お急ぎの場合は、お電話にてお問い合わせください。

今後ともJapanAnimeMapsをよろしくお願いいたします。

--
JapanAnimeMaps カスタマーサポート
Email: contact@animetourism.co.jp
Website: https://animetourism.co.jp
''',

        // 管理者向けメールの内容
        'adminEmailSubject': '【新規お問い合わせ】$managementNumber',
        'adminEmailBody': '''
新規お問い合わせが届きました。

管理番号: $managementNumber
ドキュメントID: $docId
お名前: ${_nameController.text.trim()}
メールアドレス: $_userEmail
ユーザーID: $_userId
ジャンル: $_genre
お問い合わせ内容:
${_contentController.text.trim()}
${_phoneController.text.trim().isNotEmpty ? '\nお電話番号: ${_phoneController.text.trim()}' : ''}

受付日時: ${DateTime.now().toString()}

対応をお願いします。
''',
      });

      print('✅ Email request saved to Firestore successfully');
      print('📧 Firebase Functions will process the email sending');

      // 成功ログをFirestoreに記録
      await FirebaseFirestore.instance
          .collection('email_logs')
          .add({
        'managementNumber': managementNumber,
        'docId': docId,
        'userEmail': _userEmail,
        'adminEmail': 'sota@jam-info.com',
        'fromEmail': 'noreply-contactform@animetourism.co.jp',
        'timestamp': Timestamp.now(),
        'status': 'requested_via_firestore',
        'method': 'firebase_functions',
        'note': 'Switched from mailer package to Firebase Functions due to mailer issues',
      });

      print('✅ Email log recorded successfully');

    } catch (e) {
      print('❌ ===== EMAIL REQUEST FAILED =====');
      print('❌ Error: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');

      // エラーログをFirestoreに記録
      await FirebaseFirestore.instance
          .collection('email_logs')
          .add({
        'managementNumber': managementNumber,
        'docId': docId,
        'userEmail': _userEmail,
        'timestamp': Timestamp.now(),
        'status': 'failed',
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'method': 'firebase_functions',
      });

      rethrow;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'お問い合わせ',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A0C6)),
            ),
            const SizedBox(height: 16),
            Text(
              _loadingMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'しばらくお待ちください...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black38,
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'お問い合わせフォーム',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ご不明な点やご要望がございましたら、お気軽にお問い合わせください。',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),

                // メールアドレス（自動取得・変更不可）
                _buildReadOnlyField(
                  label: 'メールアドレス',
                  value: _userEmail ?? '',
                  isRequired: true,
                ),

                // ユーザーID（自動取得・変更不可）
                _buildReadOnlyField(
                  label: 'ユーザーID',
                  value: _userId ?? '',
                  isRequired: true,
                ),

                // ジャンル（自動取得・変更不可）
                _buildReadOnlyField(
                  label: 'ジャンル',
                  value: _genre ?? '',
                  isRequired: true,
                ),

                // お名前
                _buildTextFormField(
                  label: 'お名前',
                  controller: _nameController,
                  isRequired: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'お名前を入力してください';
                    }
                    return null;
                  },
                ),

                // お問い合わせ内容
                _buildTextFormField(
                  label: 'お問い合わせ内容',
                  controller: _contentController,
                  isRequired: true,
                  maxLines: 6,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'お問い合わせ内容を入力してください';
                    }
                    if (value.trim().length < 10) {
                      return 'お問い合わせ内容は10文字以上で入力してください';
                    }
                    return null;
                  },
                ),

                // お電話番号（任意）
                _buildTextFormField(
                  label: 'お電話番号',
                  controller: _phoneController,
                  isRequired: false,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      // 電話番号の簡易チェック
                      final phoneRegex = RegExp(r'^[0-9\-\+\(\)\s]+$');
                      if (!phoneRegex.hasMatch(value.trim())) {
                        return '有効な電話番号を入力してください';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // プライバシーポリシー同意
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _isAgreed,
                      onChanged: (value) {
                        setState(() {
                          _isAgreed = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFF00A0C6),
                    ),
                    const Expanded(
                      child: Text(
                        'プライバシーポリシーに同意します。お預かりした個人情報は、お問い合わせの回答のためにのみ使用いたします。',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // 送信ボタン
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A0C6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      '送信する',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 読み取り専用フィールドを構築
  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required bool isRequired,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (isRequired)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '必須',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // テキスト入力フィールドを構築
  Widget _buildTextFormField({
    required String label,
    required TextEditingController controller,
    required bool isRequired,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (isRequired)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '必須',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '任意',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF00A0C6), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintText: maxLines > 1 ? 'お困りのことやご要望をお聞かせください' : '',
              hintStyle: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }
}