import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;

class PointHistoryPage extends StatefulWidget {
  const PointHistoryPage({Key? key}) : super(key: key);

  @override
  _PointHistoryPageState createState() => _PointHistoryPageState();
}

class _PointHistoryPageState extends State<PointHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Stream<QuerySnapshot>? _pointHistoryStream;
  User? _currentUser;
  bool _isLoading = true;
  int _totalPoints = 0;

  // 通知用
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  int _lastDocumentCount = 0;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _checkAuthAndSetupStream();
  }

  // 通知の初期化
  Future<void> _initNotifications() async {
    // iOS向け設定
    DarwinInitializationSettings initializationSettingsIOS =
    const DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    InitializationSettings initializationSettings = InitializationSettings(
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  // 通知を表示
  Future<void> _showNotification(String title, String body) async {
    const DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      0, // 通知ID
      title,
      body,
      platformChannelSpecifics,
    );
  }

  // Firebaseの認証状態を確認し、ストリームを設定
  Future<void> _checkAuthAndSetupStream() async {
    setState(() {
      _isLoading = true;
    });

    // 現在のログイン状態を確認
    _currentUser = _auth.currentUser;

    if (_currentUser != null && _currentUser!.uid.isNotEmpty) {
      // ユーザーがログインしている場合、ポイント履歴のストリームを設定
      _pointHistoryStream = _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('point_history')
          .orderBy('timestamp', descending: true)
          .snapshots();

      // 総ポイント数を取得
      try {
        final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
        if (userDoc.exists && userDoc.data()!.containsKey('points')) {
          setState(() {
            _totalPoints = userDoc.data()!['points'] ?? 0;
          });
        }
      } catch (e) {
        print('ポイント総数の取得エラー: $e');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  // ログインダイアログを表示
  Future<void> _showLoginDialog() async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.login, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text('ログイン'),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: 'メールアドレス',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    hintText: 'パスワード',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('ログイン'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                try {
                  // ログインを試行
                  await _auth.signInWithEmailAndPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop();

                  // ログイン成功後、ストリームを再設定
                  _checkAuthAndSetupStream();
                } catch (e) {
                  // エラーメッセージを表示
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('ログインエラー: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  String getAcquisitionMethod(String type) {
    switch (type) {
      case 'checkin':
      case 'check_in':
        return '聖地チェックイン';
      case 'event':
        return 'イベント参加特典';
      case 'admin':
        return 'システム付与';
      default:
        return type;
    }
  }

  String formatDate(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('yyyy/MM/dd').format(dateTime);
  }

  // アイコンを取得
  IconData getTypeIcon(String type) {
    switch (type) {
      case 'checkin':
      case 'check_in':
        return Icons.place;
      case 'event':
        return Icons.event;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.stars;
    }
  }

  // タイプに応じた色を取得
  Color getTypeColor(String type) {
    switch (type) {
      case 'checkin':
      case 'check_in':
        return Colors.green;
      case 'event':
        return Colors.blue;
      case 'admin':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'ポイント履歴',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF00008b),
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
          Icons.arrow_back_ios,
          color: Colors.white,
        ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
          ? _buildLoginPrompt()
          : _buildPointHistoryView(),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.history,
                size: 64,
                color: Color(0xFF00008b),
              ),
              const SizedBox(height: 16),
              const Text(
                'ポイント履歴を表示するには\nログインしてください',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('ログイン'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00008b),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _showLoginDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointHistoryView() {
    return Column(
      children: [
        // ポイント概要カード
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: const BoxDecoration(
            color: Color(0xFF00008b),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    '現在の保有ポイント',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _totalPoints.toString(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00008b),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'pts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 履歴リスト
        Expanded(
          child: _buildPointHistoryList(),
        ),
      ],
    );
  }

  Widget _buildPointHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _pointHistoryStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'エラーが発生しました: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'まだポイント履歴がありません',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        // ドキュメント数の変更を検出して通知を送信
        final currentDocCount = snapshot.data!.docs.length;

        if (!_isFirstLoad && currentDocCount > _lastDocumentCount) {
          // 新しい項目が追加されたとき通知を送信
          final newestDoc = snapshot.data!.docs[0];
          final data = newestDoc.data() as Map<String, dynamic>;
          final type = data['type'] as String? ?? '';
          final points = data['points'] ?? 0;

          _showNotification(
              'ポイント獲得！',
              '${getAcquisitionMethod(type)}で$pointsポイント獲得しました！'
          );
        }

        // 最初のロード時はフラグを更新するだけ
        if (_isFirstLoad) {
          _isFirstLoad = false;
        }

        // ドキュメント数を更新
        _lastDocumentCount = currentDocCount;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp;
            final points = data['points'] ?? 0;
            final type = data['type'] as String? ?? '';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: getTypeColor(type).withOpacity(0.2),
                  foregroundColor: getTypeColor(type),
                  child: Icon(getTypeIcon(type)),
                ),
                title: Text(
                  getAcquisitionMethod(type),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  formatDate(timestamp),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+$points pts',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () {
                  // タップすると詳細を表示
                  _showPointDetailDialog(data);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showPointDetailDialog(Map<String, dynamic> data) {
    final timestamp = data['timestamp'] as Timestamp;
    final points = data['points'] ?? 0;
    final type = data['type'] as String? ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(getTypeIcon(type), color: getTypeColor(type)),
            const SizedBox(width: 8),
            const Text('ポイント詳細'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('獲得方法:', getAcquisitionMethod(type)),
            const SizedBox(height: 8),
            _buildDetailRow('獲得ポイント:', '+$points pts'),
            const SizedBox(height: 8),
            _buildDetailRow('日時:', formatDate(timestamp)),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            child: const Text('閉じる'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}