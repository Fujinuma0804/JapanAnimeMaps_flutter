import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

// HTTP経由でのテストメール送信（修正版）
Future<void> testSendMailHttp(BuildContext context, String email) async {
  try {
    print('開始: HTTP経由でのFunction呼び出し');

    // Firebase Functionsの直接エンドポイントURL
    final String url = 'https://us-central1-anime-97d2d.cloudfunctions.net/testSendMail';
    print('URL: $url');

    // 現在のユーザーからIDトークンを取得
    final User? currentUser = FirebaseAuth.instance.currentUser;
    print('現在のユーザー: ${currentUser?.uid ?? "未ログイン"}');

    String? idToken;
    if (currentUser != null) {
      idToken = await currentUser.getIdToken();
      if (idToken != null) {
        print('IDトークン取得: ${idToken.substring(0, 20)}...');
      } else {
        print('IDトークンの取得に失敗しました');
      }
    }

    // リクエストヘッダーとボディを設定
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    // 認証トークンがある場合は追加
    if (idToken != null) {
      headers['Authorization'] = 'Bearer $idToken';
    }

    // リクエストの形式を修正 - dataフィールドでラップ
    final Map<String, dynamic> body = {
      'data': {  // <-- 修正: データをdataフィールドでラップ
        'emailTo': email,
      }
    };

    print('リクエスト準備完了: ${json.encode(body)}');

    // HTTP POSTリクエスト実行
    print('リクエスト送信中...');
    final http.Response response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: json.encode(body),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('リクエストがタイムアウトしました（30秒）'),
    );

    print('レスポンス受信: ステータスコード ${response.statusCode}');
    print('レスポンス本文: ${response.body}');

    // レスポンスの検証
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // 成功
      print('メール送信リクエスト成功');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$emailにテストメールを送信しました'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    } else {
      // エラーレスポンス
      Map<String, dynamic> errorData = {};
      try {
        errorData = json.decode(response.body);
      } catch (e) {
        // JSONデコードエラー
      }

      final String errorMessage = errorData['error'] != null
          ? (errorData['error']['message'] ?? 'サーバーエラー')
          : 'サーバーエラー（ステータスコード: ${response.statusCode})';
      throw Exception(errorMessage);
    }
  } catch (e) {
    print('HTTP呼び出しエラー: $e');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('エラー: $e'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
    rethrow;
  }
}

// テストメール送信ダイアログ（HTTP版）
void showTestEmailDialogHttp(BuildContext context) {
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
            title: Text('テストメール送信 (HTTP)'),
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
                    // HTTP経由で実行
                    await testSendMailHttp(context, email);

                    // 成功
                    setState(() {
                      statusMessage = '送信リクエストが完了しました';
                      statusColor = Colors.green;
                      isLoading = false;
                    });

                    // 少し待ってダイアログを閉じる
                    Future.delayed(Duration(seconds: 2), () {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                    });
                  } catch (e) {
                    // エラー処理
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