import 'dart:math';

import 'package:flutter/material.dart';
import 'package:parts/post_page/post_first/icon_setup.dart';

class ShopWelcomeScreen extends StatefulWidget {
  const ShopWelcomeScreen(
      {super.key, this.showScaffold = true // scaffoldの表示制御用パラメータを追加
      });

  final bool showScaffold;
  @override
  State<ShopWelcomeScreen> createState() => _ShopWelcomeScreenState();
}

class _ShopWelcomeScreenState extends State<ShopWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _imageOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _buttonOffset;
  bool _showButtonAnimation = false;

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

    // 2秒後にボタンアニメーションを開始
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showButtonAnimation = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 画像のフェードイン
            FadeTransition(
              opacity: _imageOpacity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Image.asset(
                  'assets/icon/jam_logo.png',
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
                  '新機能ショップようこそ！\n'
                  '人気アニメのグッズなどご購入いただけます。\n'
                  '過去のグッズから最新グッズまでご用意！\n',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // ボタン（アニメーション付き）
            if (_showButtonAnimation)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, sin(value * 4 * 3.14159) * 8),
                    child: child,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const IconSetupScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00008b),
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
              ),
          ],
        ),
      ),
    );

    // showScaffold が true の場合のみ Scaffold でラップ
    return widget.showScaffold ? Scaffold(body: content) : content;
  }
}
