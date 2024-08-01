import 'package:flutter/material.dart';
import 'package:parts/login_page/sign_up.dart';

import '../../src/page_route.dart';
import 'mail_login.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景画像
          Positioned.fill(
            child: Image.asset(
              'assets/images/sky10.png',
              fit: BoxFit.cover,
            ),
          ),
          // テキスト
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 300.0,
                  height: 50.0,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        elasticTransition(const MailLoginPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(
                        color: Colors.white, //枠線!
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'メールアドレスでログイン',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20.0,
                ),
                SizedBox(
                  width: 300.0,
                  height: 50.0,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(
                        color: Colors.white, //枠線!
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'Googleでログイン',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20.0,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      elasticTransition(const SignUpPage()),
                    );
                  },
                  child: const Text(
                    '登録がまだの方はこちら',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
