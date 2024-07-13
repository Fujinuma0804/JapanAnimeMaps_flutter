import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../src/bottomnavigationbar.dart';
import '../src/page_route.dart';
import 'sign_up.dart';

class MailSignUpPage extends StatefulWidget {
  const MailSignUpPage({Key? key}) : super(key: key);

  @override
  State<MailSignUpPage> createState() => _MailSignUpPageState();
}

class _MailSignUpPageState extends State<MailSignUpPage> {
  final _auth = FirebaseAuth.instance;
  String email = '';
  String password = '';
  String confirmPassword = '';
  bool _isObscure = true;
  bool _isObscure2 = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // AppBarの後ろに背景が表示されるようにする
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0, // AppBarを透明にするために追加
        title: const Text(
          'メールアドレスで登録',
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
              'assets/images/star.jpg',
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
                  height: 20.0,
                ),
                Center(
                  child: SizedBox(
                    width: 350.0,
                    height: 45.0,
                    child: TextFormField(
                      onChanged: (value) {
                        confirmPassword = value;
                      },
                      obscureText: _isObscure2, // パスワードの非表示設定
                      style: const TextStyle(
                        color: Colors.white, // 入力されるテキストの色を白色に設定
                      ),
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _isObscure2 = !_isObscure2;
                            });
                          },
                          icon: Icon(
                            _isObscure2
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white,
                          ),
                        ),
                        labelText: 'パスワードを再度入力',
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
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text(
                            '登録',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(
                  height: 35.0,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      elasticTransition(const SignUpPage()),
                    );
                  },
                  child: const Text(
                    '登録済みの方はこちら',
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

  void _signUp() async {
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('パスワードが一致しません。'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newUser = await _auth.createUserWithEmailAndPassword(
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
        case 'email-already-in-use':
          errorMessage = 'このメールアドレスは既に使用されています。';
          break;
        case 'invalid-email':
          errorMessage = 'メールアドレスのフォーマットが正しくありません。';
          break;
        case 'weak-password':
          errorMessage = 'パスワードが簡単すぎます。';
          break;
        default:
          errorMessage = '登録に失敗しました。もう一度お試しください。';
          break;
      }
      // Print error code and message for debugging purposes
      print('Error code: ${e.code}');
      print('Error message: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
        ),
      );
    } catch (e) {
      // Print the error for any other exceptions
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('登録に失敗しました。もう一度お試しください。'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
