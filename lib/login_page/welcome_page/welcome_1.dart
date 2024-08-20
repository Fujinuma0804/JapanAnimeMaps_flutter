import 'package:flutter/material.dart';
import 'package:parts/login_page/welcome_page/welcome_2.dart';

class Welcome1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            // イメージを表示
            Image.asset(
              'assets/images/Welcome-amico.png', // あなたの画像パスに変更してください
              height: 200,
            ),
            SizedBox(height: 40),
            // タイトルテキスト
            Text(
              'JAMへようこそ',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            // 説明テキスト
            Text(
              'JAMアプリで聖地巡礼をより楽しく。\nポイントも貯まって、同じアニメが好きなユーザと交流しよう。',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            Spacer(),
            // 次へボタン
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => Welcome2()));
                  // 次の画面へのナビゲーションなど
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0B3D91), // ボタンの背景色
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
                child: Text(
                  '次へ',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
