import 'package:flutter/material.dart';

import '../src/page_route.dart';
import 'sign_up.dart';

class MailLoginPage extends StatefulWidget {
  const MailLoginPage({Key? key}) : super(key: key);

  @override
  State<MailLoginPage> createState() => _MailLoginPageState();
}

String email = '';
String password = '';
bool _isObscure = true;

class _MailLoginPageState extends State<MailLoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // AppBarの後ろに背景が表示されるようにする
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0, // AppBarを透明にするために追加
        title: const Text(
          'メールアドレスでログイン',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ), // タイトルのテキスト色を白にする
        ),
      ),
      body: Stack(
        children: [
          // 背景画像
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_login.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // テキスト
          const SizedBox(
            height: 50.0,
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: SizedBox(
                    width: 350.0,
                    height: 45.0,
                    child: TextFormField(
                      onChanged: (value) {
                        email = value;
                      },
                      style: const TextStyle(
                        color: Colors.white, // 入力されるテキストの色を白色に設定
                      ),
                      decoration: const InputDecoration(
                        labelText: 'メールアドレスを入力',
                        labelStyle: TextStyle(
                          color: Colors.white, // labelTextの色を白色に設定
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white, // 枠線の色を指定
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white, // 有効時の枠線の色
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white, // フォーカス時の枠線の色
                          ),
                        ),
                      ),
                      textAlign: TextAlign.left, // Align text input to the left
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20.0,
                ),
                Center(
                  child: SizedBox(
                    width: 350.0,
                    height: 45.0,
                    child: TextFormField(
                      onChanged: (value) {
                        password = value;
                      },
                      obscureText: _isObscure, // パスワードの非表示設定
                      style: const TextStyle(
                        color: Colors.white, // 入力されるテキストの色を白色に設定
                      ),
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _isObscure = !_isObscure;
                            });
                          },
                          icon: Icon(
                            _isObscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white,
                          ),
                        ),
                        labelText: 'パスワードを入力',
                        labelStyle: const TextStyle(
                          color: Colors.white, // labelTextの色を白色に設定
                        ),
                        border: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white, // 枠線の色を指定
                          ),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white, // 有効時の枠線の色
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white, // フォーカス時の枠線の色
                          ),
                        ),
                      ),
                      textAlign: TextAlign.left, // Align text input to the left
                    ),
                  ),
                ),
                const SizedBox(
                  height: 50.0,
                ),
                SizedBox(
                  height: 50.0,
                  width: 200.0,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      side: const BorderSide(
                        color: Colors.white,
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                    onPressed: () {},
                    child: const Text(
                      'ログイン',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 40.0,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      elasticTransition(const SignUpPage()),
                    );
                  },
                  child: const Text(
                    'パスワード忘れた方はこちら',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      elasticTransition(const SignUpPage()),
                    );
                  },
                  child: const Text(
                    '会員登録がまだの方はこちら',
                    style: TextStyle(
                      color: Colors.white,
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
