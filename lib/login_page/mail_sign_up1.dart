import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 追加
import 'package:parts/login_page/login_page.dart';

import 'mail_sign_up2.dart';

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
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'メールアドレスで登録',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/top.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
              ),
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
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'メールアドレスを入力',
                          labelStyle: TextStyle(
                            color: Colors.white,
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        textAlign: TextAlign.left,
                        keyboardType:
                            TextInputType.emailAddress, // メールアドレス用のキーボードタイプを指定
                        inputFormatters: [
                          FilteringTextInputFormatter.singleLineFormatter
                        ], // 複数行の入力を防ぐためのフォーマッター
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  Center(
                    child: SizedBox(
                      width: 350.0,
                      height: 45.0,
                      child: TextFormField(
                        onChanged: (value) {
                          password = value;
                        },
                        obscureText: _isObscure,
                        style: const TextStyle(
                          color: Colors.white,
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
                            color: Colors.white,
                          ),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                            ),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  Center(
                    child: SizedBox(
                      width: 350.0,
                      height: 45.0,
                      child: TextFormField(
                        onChanged: (value) {
                          confirmPassword = value;
                        },
                        obscureText: _isObscure,
                        style: const TextStyle(
                          color: Colors.white,
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
                          labelText: 'パスワードを再度入力',
                          labelStyle: const TextStyle(
                            color: Colors.white,
                          ),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                            ),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                  const SizedBox(height: 50.0),
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
                      onPressed: _isLoading ? null : _next,
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : const Text(
                              '次へ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 25.0),
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
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginPage()));
                      },
                      child: const Text(
                        '戻る',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 35.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _next() {
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正しい形式のメールアドレスを入力してください。'),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('パスワードが一致しません。'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecondSignUpPage(
          email: email,
          password: password,
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    // 正規表現を用いてメールアドレスの形式をチェック
    // メールアドレスの形式は各種の正規表現パターンで表されますが、一例として以下のパターンを利用しています。
    // 実際の使用に応じて適切なパターンを選択してください。
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegExp.hasMatch(email);
  }
}
