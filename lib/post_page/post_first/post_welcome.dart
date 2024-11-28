import 'package:flutter/material.dart';
import 'package:parts/post_page/post_first/icon_setup.dart';

class PostWelcome1 extends StatefulWidget {
  const PostWelcome1({super.key});

  @override
  State<PostWelcome1> createState() => _PostWelcome1State();
}

class _PostWelcome1State extends State<PostWelcome1>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _imageOpacity;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // 画像のフェードインアニメーション (0-1秒)
    _imageOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // テキストのフェードインアニメーション (1-2秒)
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // 画像のフェードイン
                  FadeTransition(
                    opacity: _imageOpacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: Image.asset(
                        'assets/icon/jam_logo.png', // アセットに画像を追加してください
                        height: 300,
                      ),
                    ),
                  ),
                  // テキストのフェードイン
                  FadeTransition(
                    opacity: _textOpacity,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        '新機能コミュニティへようこそ！\n'
                        '本機能ではリアルタイムな情報や\n'
                        'ユーザ同士の交流が可能になります。\n',
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 下部の「次へ」ボタン
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // 次の画面へ遷移
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) =>
                            const IconSetupScreen(), // 次の画面のウィジェット
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00008b),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text(
                    'まずは初期設定から',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
