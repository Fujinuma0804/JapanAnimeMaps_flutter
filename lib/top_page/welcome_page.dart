import 'package:flutter/material.dart';
import 'package:parts/login_page/sign_up.dart';

import '../../src/page_route.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景画像
          Positioned.fill(
            child: Image.asset(
              'assets/images/top.png',
              fit: BoxFit.cover,
            ),
          ),
          // テキスト
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  elasticTransition(const SignUpPage()),
                );
              },
              child: const Text(
                'start',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    // Shadow(
                    //   blurRadius: 10.0,
                    //   color: Colors.black,
                    //   offset: Offset(5.0, 5.0),
                    // ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
