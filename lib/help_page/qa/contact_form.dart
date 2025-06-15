import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'qa_form_thanks.dart';

class ContactFormPage extends StatefulWidget {
  const ContactFormPage({Key? key}) : super(key: key);

  @override
  State<ContactFormPage> createState() => _ContactFormPageState();
}

class _ContactFormPageState extends State<ContactFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isAgreed = false;
  bool _isLoading = false;
  String _loadingMessage = '送信中...';

  String? _userEmail;
  String? _userId;

  // SMTP設定（実際の値に変更してください）
  static const String _smtpHost = 'mail19.onamae.ne.jp'; // SMTPサーバーホスト
  static const int _smtpPort = 465; // SMTPポート
  static const String _smtpUsername = 'noreply-contactform@animetourism.co.jp'; // SMTPユーザー名
  static const String _smtpPassword = '10172002Sota@'; // SMTPパスワード（アプリパスワード推奨）
  static const String _adminEmail = 'app-customer-admin@jam-info.com'; // 管理者メールアドレス

  // プライバシーポリシーのURL
  static const String _privacyPolicyUrl = 'https://animetourism.co.jp/privacy'; // 実際のURLに変更してください

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
        });
      } else {
        print('⚠️ No user logged in, using guest mode');
        setState(() {
          _userEmail = 'ゲストユーザー';
          _userId = 'guest_user';
        });
      }
      print('✅ User data initialized: Email=$_userEmail');
    } catch (e) {
      print('❌ Error initializing user data: $e');
      setState(() {
        _userEmail = 'ゲストユーザー';
        _userId = 'guest_user';
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

  // SMTP設定を取得
  SmtpServer _getSmtpServer() {
    return SmtpServer(
      _smtpHost,
      port: _smtpPort,
      username: _smtpUsername,
      password: _smtpPassword,
      allowInsecure: false,
      ssl: true, // SSLを使用
    );
  }

  // 受付完了メールを送信（ユーザー向け）
  Future<void> _sendConfirmationEmail(String managementNumber) async {
    try {
      print('📧 Sending confirmation email to user...');

      final smtpServer = _getSmtpServer();

      final message = Message()
        ..from = Address(_smtpUsername, 'JapanAnimeMaps')
        ..recipients.add(_userEmail!)
        ..subject = '【JapanAnimeMaps】お問い合わせを受け付けました'
        ..text = '''
${_nameController.text.trim()} 様

この度は、JapanAnimeMapsにお問い合わせいただき、ありがとうございます。
以下の内容でお問い合わせを受け付けいたしました。

管理番号: $managementNumber
お名前: ${_nameController.text.trim()}
メールアドレス: $_userEmail
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
'''
        ..html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>お問い合わせありがとうございます</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Hiragino Sans', 'Yu Gothic', 'Meiryo', sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh;">
  
  <!-- メインコンテナ -->
  <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; box-shadow: 0 10px 30px rgba(0,0,0,0.1);">
    
    <!-- ヘッダー -->
    <div style="background: linear-gradient(135deg, #00A0C6 0%, #0077B5 100%); padding: 40px 30px; text-align: center; position: relative; overflow: hidden;">
      <div style="position: absolute; top: -50px; right: -50px; width: 100px; height: 100px; background: rgba(255,255,255,0.1); border-radius: 50%; animation: float 3s ease-in-out infinite;"></div>
      <div style="position: absolute; bottom: -30px; left: -30px; width: 60px; height: 60px; background: rgba(255,255,255,0.1); border-radius: 50%; animation: float 3s ease-in-out infinite reverse;"></div>
      <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold; text-shadow: 0 2px 4px rgba(0,0,0,0.2);">
        ✨ お問い合わせありがとうございます
      </h1>
      <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 16px;">
        JapanAnimeMaps カスタマーサポート
      </p>
    </div>

    <!-- メインコンテンツ -->
    <div style="padding: 40px 30px;">
      
      <!-- 挨拶 -->
      <div style="text-align: center; margin-bottom: 35px;">
        <h2 style="color: #333; font-size: 24px; margin: 0 0 15px 0; font-weight: bold;">
          ${_nameController.text.trim()} 様
        </h2>
        <p style="color: #666; font-size: 16px; line-height: 1.6; margin: 0;">
          この度は、JapanAnimeMapsにお問い合わせいただき、<br>
          誠にありがとうございます。<br>
          以下の内容でお問い合わせを受け付けいたしました。
        </p>
      </div>

      <!-- お問い合わせ内容カード -->
      <div style="background: linear-gradient(135deg, #f8f9ff 0%, #e8f4f8 100%); border-radius: 15px; padding: 30px; margin: 30px 0; border-left: 5px solid #00A0C6; box-shadow: 0 5px 15px rgba(0,160,198,0.1);">
        
        <div style="display: flex; align-items: center; margin-bottom: 25px;">
          <div style="width: 40px; height: 40px; background: linear-gradient(135deg, #00A0C6, #0077B5); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin-right: 15px;">
            <span style="color: white; font-size: 20px;">📋</span>
          </div>
          <h3 style="color: #00A0C6; margin: 0; font-size: 20px; font-weight: bold;">受付内容</h3>
        </div>

        <div style="background: white; border-radius: 10px; padding: 25px; box-shadow: 0 2px 8px rgba(0,0,0,0.05);">
          
          <div style="margin-bottom: 20px;">
            <div style="display: inline-block; background: #00A0C6; color: white; padding: 8px 15px; border-radius: 20px; font-size: 14px; font-weight: bold; margin-bottom: 10px;">
              管理番号
            </div>
            <p style="font-size: 18px; font-weight: bold; color: #333; margin: 0; font-family: 'Courier New', monospace; background: #f8f9fa; padding: 10px; border-radius: 5px; border: 2px dashed #00A0C6;">
              $managementNumber
            </p>
          </div>

          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 25px;">
            <div>
              <p style="color: #00A0C6; font-weight: bold; margin: 0 0 8px 0; font-size: 14px;">👤 お名前</p>
              <p style="color: #333; margin: 0; font-size: 16px; background: #f8f9fa; padding: 10px; border-radius: 5px;">
                ${_nameController.text.trim()}
              </p>
            </div>
            <div>
              <p style="color: #00A0C6; font-weight: bold; margin: 0 0 8px 0; font-size: 14px;">📧 メールアドレス</p>
              <p style="color: #333; margin: 0; font-size: 16px; background: #f8f9fa; padding: 10px; border-radius: 5px; word-break: break-all;">
                $_userEmail
              </p>
            </div>
          </div>

          <div style="margin-bottom: 20px;">
            <p style="color: #00A0C6; font-weight: bold; margin: 0 0 12px 0; font-size: 14px;">💬 お問い合わせ内容</p>
            <div style="background: #f8f9fa; border: 2px solid #e9ecef; border-radius: 10px; padding: 20px;">
              <p style="color: #333; margin: 0; font-size: 16px; line-height: 1.8; white-space: pre-line;">
                ${_contentController.text.trim()}
              </p>
            </div>
          </div>

          ${_phoneController.text.trim().isNotEmpty ? '''
          <div>
            <p style="color: #00A0C6; font-weight: bold; margin: 0 0 8px 0; font-size: 14px;">📞 お電話番号</p>
            <p style="color: #333; margin: 0; font-size: 16px; background: #f8f9fa; padding: 10px; border-radius: 5px;">
              ${_phoneController.text.trim()}
            </p>
          </div>
          ''' : ''}
        </div>
      </div>

      <!-- 対応について -->
      <div style="text-align: center; background: linear-gradient(135deg, #fff3cd 0%, #ffeaa7 100%); border-radius: 15px; padding: 25px; margin: 30px 0; border: 2px solid #ffc107;">
        <div style="font-size: 30px; margin-bottom: 15px;">⏰</div>
        <h3 style="color: #856404; margin: 0 0 10px 0; font-size: 18px; font-weight: bold;">対応について</h3>
        <p style="color: #856404; margin: 0; font-size: 16px; line-height: 1.6;">
          通常<strong>3営業日以内</strong>にご返答いたします<br>
        </p>
      </div>

      <!-- 感謝メッセージ -->
      <div style="text-align: center; margin: 35px 0;">
        <p style="color: #666; font-size: 16px; line-height: 1.8; margin: 0;">
          今後とも<strong>JapanAnimeMaps</strong>を<br>
          よろしくお願いいたします。
        </p>
      </div>
    </div>

    <!-- フッター -->
    <div style="background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%); padding: 30px; text-align: center;">
      <div style="margin-bottom: 20px;">
        <h4 style="color: #ffffff; margin: 0 0 15px 0; font-size: 20px; font-weight: bold;">
          JapanAnimeMaps カスタマーサポート
        </h4>
        <div style="display: flex; justify-content: center; align-items: center; gap: 20px; flex-wrap: wrap;">
          <div style="display: flex; align-items: center; gap: 8px;">
            <span style="color: #00A0C6; font-size: 18px;">📧</span>
            <a href="mailto:contact@animetourism.co.jp" style="color: #00A0C6; text-decoration: none; font-weight: bold;">
              contact@animetourism.co.jp
            </a>
          </div>
          <div style="display: flex; align-items: center; gap: 8px;">
            <span style="color: #00A0C6; font-size: 18px;">🌐</span>
            <a href="https://animetourism.co.jp" style="color: #00A0C6; text-decoration: none; font-weight: bold;">
              https://animetourism.co.jp
            </a>
          </div>
        </div>
      </div>
      <div style="border-top: 1px solid rgba(255,255,255,0.2); padding-top: 20px;">
        <p style="color: rgba(255,255,255,0.7); margin: 0; font-size: 14px;">
          © 2024-2025 AnimeTourism Inc. All rights reserved.
        </p>
      </div>
    </div>
  </div>

  <style>
    @keyframes float {
      0%, 100% { transform: translateY(0px); }
      50% { transform: translateY(-10px); }
    }
  </style>
</body>
</html>
''';

      final sendReport = await send(message, smtpServer);
      print('✅ Confirmation email sent successfully: ${sendReport.toString()}');

    } catch (e) {
      print('❌ Failed to send confirmation email: $e');
      rethrow;
    }
  }

  // 問い合わせ通知メールを送信（管理者向け）
  Future<void> _sendNotificationEmail(String managementNumber, String docId) async {
    try {
      print('📧 Sending notification email to admin...');

      final smtpServer = _getSmtpServer();

      final message = Message()
        ..from = Address(_smtpUsername, 'JapanAnimeMaps Contact Form')
        ..recipients.add(_adminEmail)
        ..subject = '【新規お問い合わせ】$managementNumber'
        ..text = '''
新規お問い合わせが届きました。

管理番号: $managementNumber
ドキュメントID: $docId
お名前: ${_nameController.text.trim()}
メールアドレス: $_userEmail
ユーザーID: $_userId
お問い合わせ内容:
${_contentController.text.trim()}
${_phoneController.text.trim().isNotEmpty ? '\nお電話番号: ${_phoneController.text.trim()}' : ''}

受付日時: ${DateTime.now().toString()}

対応をお願いします。
'''
        ..html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>新規お問い合わせ通知</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Hiragino Sans', 'Yu Gothic', 'Meiryo', sans-serif; background: linear-gradient(135deg, #ff6b6b 0%, #ee5a52 100%); min-height: 100vh;">
  
  <!-- メインコンテナ -->
  <div style="max-width: 700px; margin: 20px auto; background-color: #ffffff; border-radius: 15px; box-shadow: 0 15px 35px rgba(0,0,0,0.1); overflow: hidden;">
    
    <!-- 緊急ヘッダー -->
    <div style="background: linear-gradient(135deg, #dc3545 0%, #c82333 100%); padding: 30px; text-align: center; position: relative;">
      <div style="position: absolute; top: 10px; right: 20px; background: rgba(255,255,255,0.2); border-radius: 50%; width: 60px; height: 60px; display: flex; align-items: center; justify-content: center; animation: pulse 2s infinite;">
        <span style="color: white; font-size: 24px;">🚨</span>
      </div>
      <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold; text-shadow: 0 2px 4px rgba(0,0,0,0.3);">
        🔔 新規お問い合わせ
      </h1>
      <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 16px; font-weight: bold;">
        至急対応が必要です
      </p>
    </div>

    <!-- 管理番号バッジ -->
    <div style="padding: 20px 30px; background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%); border-bottom: 3px solid #dc3545;">
      <div style="text-align: center;">
        <p style="color: #666; margin: 0 0 10px 0; font-size: 14px; font-weight: bold;">管理番号</p>
        <div style="display: inline-block; background: linear-gradient(135deg, #dc3545, #c82333); color: white; padding: 15px 30px; border-radius: 30px; font-size: 20px; font-weight: bold; font-family: 'Courier New', monospace; box-shadow: 0 5px 15px rgba(220,53,69,0.3);">
          $managementNumber
        </div>
      </div>
    </div>

    <!-- メインコンテンツ -->
    <div style="padding: 30px;">
      
      <!-- 顧客情報カード -->
      <div style="background: linear-gradient(135deg, #e3f2fd 0%, #bbdefb 100%); border-radius: 15px; padding: 25px; margin-bottom: 25px; border-left: 5px solid #2196f3;">
        <div style="display: flex; align-items: center; margin-bottom: 20px;">
          <div style="width: 40px; height: 40px; background: linear-gradient(135deg, #2196f3, #1976d2); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin-right: 15px;">
            <span style="color: white; font-size: 20px;">👤</span>
          </div>
          <h3 style="color: #1976d2; margin: 0; font-size: 18px; font-weight: bold;">顧客情報</h3>
        </div>

        <div style="background: white; border-radius: 10px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.05);">
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 15px;">
            <div>
              <p style="color: #1976d2; font-weight: bold; margin: 0 0 5px 0; font-size: 12px; text-transform: uppercase;">お名前</p>
              <p style="color: #333; margin: 0; font-size: 16px; font-weight: bold; background: #f8f9fa; padding: 8px; border-radius: 5px;">
                ${_nameController.text.trim()}
              </p>
            </div>
            <div>
              <p style="color: #1976d2; font-weight: bold; margin: 0 0 5px 0; font-size: 12px; text-transform: uppercase;">📧 メールアドレス</p>
              <a href="mailto:$_userEmail" style="color: #dc3545; text-decoration: none; font-size: 16px; font-weight: bold; background: #f8f9fa; padding: 8px; border-radius: 5px; display: block; word-break: break-all;">
                $_userEmail
              </a>
            </div>
          </div>

          <div>
            <p style="color: #1976d2; font-weight: bold; margin: 0 0 5px 0; font-size: 12px; text-transform: uppercase;">🆔 ユーザーID / ドキュメントID</p>
            <p style="color: #666; margin: 0; font-size: 14px; font-family: 'Courier New', monospace; background: #f8f9fa; padding: 8px; border-radius: 5px;">
              User: $_userId<br>
              Doc: $docId
            </p>
          </div>
        </div>
      </div>

      <!-- お問い合わせ内容カード -->
      <div style="background: linear-gradient(135deg, #fff3e0 0%, #ffe0b2 100%); border-radius: 15px; padding: 25px; margin-bottom: 25px; border-left: 5px solid #ff9800;">
        <div style="display: flex; align-items: center; margin-bottom: 20px;">
          <div style="width: 40px; height: 40px; background: linear-gradient(135deg, #ff9800, #f57c00); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin-right: 15px;">
            <span style="color: white; font-size: 20px;">💬</span>
          </div>
          <h3 style="color: #f57c00; margin: 0; font-size: 18px; font-weight: bold;">お問い合わせ内容</h3>
        </div>

        <div style="background: white; border-radius: 10px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.05);">
          <div style="background: #f8f9fa; border: 2px solid #e9ecef; border-radius: 10px; padding: 20px; position: relative;">
            <div style="position: absolute; top: -10px; left: 20px; background: linear-gradient(135deg, #ff9800, #f57c00); color: white; padding: 5px 15px; border-radius: 15px; font-size: 12px; font-weight: bold;">
              INQUIRY CONTENT
            </div>
            <p style="color: #333; margin: 15px 0 0 0; font-size: 16px; line-height: 1.8; white-space: pre-line;">
              ${_contentController.text.trim()}
            </p>
          </div>

          ${_phoneController.text.trim().isNotEmpty ? '''
          <div style="margin-top: 15px;">
            <p style="color: #f57c00; font-weight: bold; margin: 0 0 5px 0; font-size: 12px; text-transform: uppercase;">📞 お電話番号</p>
            <a href="tel:${_phoneController.text.trim()}" style="color: #dc3545; text-decoration: none; font-size: 16px; font-weight: bold; background: #f8f9fa; padding: 8px; border-radius: 5px; display: inline-block;">
              ${_phoneController.text.trim()}
            </a>
          </div>
          ''' : ''}
        </div>
      </div>

      <!-- 受付情報カード -->
      <div style="background: linear-gradient(135deg, #e8f5e8 0%, #c8e6c9 100%); border-radius: 15px; padding: 25px; margin-bottom: 25px; border-left: 5px solid #4caf50;">
        <div style="display: flex; align-items: center; margin-bottom: 15px;">
          <div style="width: 40px; height: 40px; background: linear-gradient(135deg, #4caf50, #388e3c); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin-right: 15px;">
            <span style="color: white; font-size: 20px;">📅</span>
          </div>
          <h3 style="color: #388e3c; margin: 0; font-size: 18px; font-weight: bold;">受付情報</h3>
        </div>

        <div style="background: white; border-radius: 10px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.05);">
          <p style="color: #388e3c; font-weight: bold; margin: 0 0 10px 0; font-size: 14px;">受付日時</p>
          <p style="color: #333; margin: 0; font-size: 16px; font-weight: bold; background: #f8f9fa; padding: 10px; border-radius: 5px; font-family: 'Courier New', monospace;">
            ${DateTime.now().toString()}
          </p>
        </div>
      </div>

      <!-- アクションボタン -->
      <div style="text-align: center; background: linear-gradient(135deg, #ffebee 0%, #ffcdd2 100%); border-radius: 15px; padding: 25px; border: 2px solid #f44336;">
        <div style="font-size: 30px; margin-bottom: 15px;">⚡</div>
        <h3 style="color: #d32f2f; margin: 0 0 15px 0; font-size: 20px; font-weight: bold;">至急対応をお願いします</h3>
        <p style="color: #d32f2f; margin: 0; font-size: 16px; font-weight: bold;">
          お客様への迅速な対応をお願いいたします
        </p>
      </div>
    </div>

    <!-- フッター -->
    <div style="background: linear-gradient(135deg, #263238 0%, #37474f 100%); padding: 25px; text-align: center;">
      <h4 style="color: #ffffff; margin: 0 0 10px 0; font-size: 18px; font-weight: bold;">
        JapanAnimeMaps 管理システム
      </h4>
      <p style="color: rgba(255,255,255,0.7); margin: 0; font-size: 14px;">
        このメールは自動送信されています
      </p>
    </div>
  </div>

  <style>
    @keyframes pulse {
      0% { transform: scale(1); opacity: 1; }
      50% { transform: scale(1.1); opacity: 0.8; }
      100% { transform: scale(1); opacity: 1; }
    }
  </style>
</body>
</html>
''';

      final sendReport = await send(message, smtpServer);
      print('✅ Notification email sent successfully: ${sendReport.toString()}');

    } catch (e) {
      print('❌ Failed to send notification email: $e');
      rethrow;
    }
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

      // Firestoreにデータを保存
      final docRef = await FirebaseFirestore.instance
          .collection('inquiries')
          .add({
        'managementNumber': managementNumber,
        'userEmail': _userEmail,
        'userId': _userId,
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

      // メール送信
      setState(() {
        _loadingMessage = '内容を送信中...';
      });

      await _sendEmailsInBackground(managementNumber, docRef.id);

      print('🎯 Navigating to thanks page...');

      // 完了画面へ遷移
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QAFormThanksPage(
              managementNumber: managementNumber,
              inquiryData: {
                'name': _nameController.text.trim(),
                'email': _userEmail!,
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
        } else if (e.toString().contains('SMTP') || e.toString().contains('mail')) {
          errorMessage = 'メール送信に失敗しました。お問い合わせは登録されましたが、確認メールが届かない場合があります。';
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

  // メール送信をバックグラウンドで実行
  Future<void> _sendEmailsInBackground(String managementNumber, String docId) async {
    try {
      print('📧 Starting email sending process...');

      // 1. 受付完了メール（ユーザー向け）を送信
      await _sendConfirmationEmail(managementNumber);

      // 2. 問い合わせ通知メール（管理者向け）を送信
      await _sendNotificationEmail(managementNumber, docId);

      // 成功ログをFirestoreに記録
      await FirebaseFirestore.instance
          .collection('email_logs')
          .add({
        'managementNumber': managementNumber,
        'docId': docId,
        'userEmail': _userEmail,
        'adminEmail': _adminEmail,
        'fromEmail': _smtpUsername,
        'timestamp': Timestamp.now(),
        'status': 'success',
        'method': 'smtp_direct',
        'smtpHost': _smtpHost,
        'smtpPort': _smtpPort,
      });

      print('✅ All emails sent successfully');

    } catch (e) {
      print('❌ Email sending failed: $e');

      // エラーログをFirestoreに記録
      await FirebaseFirestore.instance
          .collection('email_logs')
          .add({
        'managementNumber': managementNumber,
        'docId': docId,
        'userEmail': _userEmail,
        'adminEmail': _adminEmail,
        'fromEmail': _smtpUsername,
        'timestamp': Timestamp.now(),
        'status': 'failed',
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'method': 'smtp_direct',
        'smtpHost': _smtpHost,
        'smtpPort': _smtpPort,
      });

      rethrow;
    }
  }

  // プライバシーポリシーをアプリ内ブラウザで開く
  Future<void> _openPrivacyPolicy() async {
    try {
      final Uri url = Uri.parse(_privacyPolicyUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.inAppWebView, // アプリ内ブラウザで開く
          webViewConfiguration: const WebViewConfiguration(
            headers: <String, String>{'my_header_key': 'my_header_value'},
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('プライバシーポリシーを開けませんでした'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error opening privacy policy: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プライバシーポリシーを開けませんでした'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                      final phoneRegex = RegExp(r'^[0-9\-\+\(\)\s]+'
                      );
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
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                          children: [
                            TextSpan(
                              text: 'プライバシーポリシー',
                              style: const TextStyle(
                                color: Color(0xFF00A0C6),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = _openPrivacyPolicy,
                            ),
                            const TextSpan(
                              text: 'に同意します。お預かりした個人情報は、お問い合わせの回答のためにのみ使用いたします。',
                            ),
                          ],
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