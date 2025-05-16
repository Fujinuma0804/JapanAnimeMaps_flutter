import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Firebase初期化状態をチェックする関数
Future<bool> _isFirebaseInitialized() async {
  try {
    final apps = Firebase.apps;
    print('Firebase apps: ${apps.length}');
    return apps.isNotEmpty;
  } catch (e) {
    print('Firebase initialization check error: $e');
    return false;
  }
}

// テストメール送信ダイアログを表示する関数
void showTestEmailDialog(BuildContext context) {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  String statusMessage = 'メールアドレスを入力してください';
  Color statusColor = Colors.black;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('テストメール送信'),
            content: Container(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusMessage,
                      style: TextStyle(color: statusColor),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'メールアドレス',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isLoading,
                  ),
                  if (isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () {
                  Navigator.of(context).pop();
                },
                child: Text('キャンセル'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00008b),
                ),
                onPressed: isLoading ? null : () async {
                  final email = emailController.text.trim();

                  if (email.isEmpty) {
                    setState(() {
                      statusMessage = 'メールアドレスを入力してください';
                      statusColor = Colors.red;
                    });
                    return;
                  }

                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                    setState(() {
                      statusMessage = '有効なメールアドレスを入力してください';
                      statusColor = Colors.red;
                    });
                    return;
                  }

                  setState(() {
                    isLoading = true;
                    statusMessage = '送信処理を開始しています...';
                    statusColor = Colors.blue;
                  });

                  try {
                    // Firebaseの初期化状態を確認
                    setState(() {
                      statusMessage = 'Firebase初期化状態を確認中...';
                    });

                    bool initialized = await _isFirebaseInitialized();
                    if (!initialized) {
                      throw Exception('Firebaseが初期化されていません');
                    }

                    setState(() {
                      statusMessage = 'Cloud Functions接続中...';
                    });

                    // 利用可能なプラグインの情報を表示
                    setState(() {
                      statusMessage = 'プラグイン情報を確認中...';
                    });

                    // リージョン指定で明示的にインスタンス化
                    setState(() {
                      statusMessage = 'Functions初期化中 (asia-northeast1)...';
                    });

                    final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
                      region: 'asia-northeast1',
                    );

                    setState(() {
                      statusMessage = 'testSendMail関数を呼び出し中...';
                    });

                    try {
                      final HttpsCallable callable = functions.httpsCallable('testSendMail');

                      setState(() {
                        statusMessage = 'パラメータを設定中...';
                      });

                      final params = {'emailTo': email};
                      print('Calling with params: $params');

                      setState(() {
                        statusMessage = '関数実行中...';
                      });

                      final result = await callable.call(params);

                      setState(() {
                        statusMessage = '送信成功！結果: ${result.data}';
                        statusColor = Colors.green;
                        isLoading = false;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$emailにテストメールを送信しました'),
                          backgroundColor: Colors.green,
                        ),
                      );

                      Future.delayed(Duration(seconds: 2), () {
                        if (Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                      });
                    } catch (functionError) {
                      print('Function call error: $functionError');
                      setState(() {
                        statusMessage = 'Cloud Function呼び出しエラー: $functionError';
                        statusColor = Colors.red;
                        isLoading = false;
                      });
                    }
                  } catch (e) {
                    print('テストメール送信エラー: $e');
                    setState(() {
                      statusMessage = 'エラー: $e';
                      statusColor = Colors.red;
                      isLoading = false;
                    });
                  }
                },
                child: Text('送信', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}