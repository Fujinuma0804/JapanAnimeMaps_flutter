import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../src/bottomnavigationbar.dart';
import '../src/page_route.dart';
import 'sign_up.dart';

class MailLoginPage extends StatefulWidget {
  const MailLoginPage({Key? key}) : super(key: key);

  @override
  State<MailLoginPage> createState() => _MailLoginPageState();
}

class _MailLoginPageState extends State<MailLoginPage> {
  final _auth = FirebaseAuth.instance;
  String email = '';
  String password = '';
  bool _isObscure = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // AppBarの後ろに背景が表示されるようにする
      appBar: AppBar(
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
              'assets/images/top.png',
              fit: BoxFit.cover,
            ),
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
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text(
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

  void _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newUser = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      if (newUser != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'メールアドレスのフォーマットが正しくありません';
          break;
        case 'user-disabled':
          errorMessage = '現在指定したメールアドレスは使用できません';
          break;
        case 'user-not-found':
          errorMessage = '指定したメールアドレスは登録されていません';
          break;
        case 'wrong-password':
          errorMessage = 'パスワードが間違っています';
          break;
        default:
          errorMessage = 'ログインに失敗しました。もう一度お試しください。';
          break;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
