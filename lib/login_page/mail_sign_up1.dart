import 'package:cloud_firestore/cloud_firestore.dart'; // 追加
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parts/login_page/login_page.dart';

import 'mail_sign_up2.dart';

class MailSignUpPage extends StatefulWidget {
  const MailSignUpPage({Key? key}) : super(key: key);

  @override
  State<MailSignUpPage> createState() => _MailSignUpPageState();
}

class _MailSignUpPageState extends State<MailSignUpPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance; // 追加

  String email = '';
  String password = '';
  String confirmPassword = '';

  bool _isObscure = true;
  bool _isObscure2 = true;
  bool _isLoading = false;
  String _language = '日本語';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false, // レイアウトが上がらないように変更
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _language == '日本語' ? 'メールアドレスで登録' : 'Sign Up with Email',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          DropdownButton<String>(
            value: _language,
            dropdownColor: Colors.black,
            icon: const Icon(Icons.language, color: Colors.white),
            underline: Container(
              height: 2,
              color: Colors.transparent,
            ),
            onChanged: (String? newValue) {
              setState(() {
                _language = newValue!;
              });
            },
            items: <String>['日本語', 'English']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0), // 追加
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
                          decoration: InputDecoration(
                            labelText: _language == '日本語'
                                ? 'メールアドレスを入力'
                                : 'Enter Email Address',
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
                          keyboardType: TextInputType.emailAddress,
                          inputFormatters: [
                            FilteringTextInputFormatter.singleLineFormatter
                          ],
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
                            labelText: _language == '日本語'
                                ? 'パスワードを入力'
                                : 'Enter Password',
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
                          obscureText: _isObscure2,
                          style: const TextStyle(
                            color: Colors.white,
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
                            labelText: _language == '日本語'
                                ? 'パスワードを再度入力'
                                : 'Re-enter Password',
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
                            : Text(
                                _language == '日本語' ? '次へ' : 'Next',
                                style: const TextStyle(
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
                        child: Text(
                          _language == '日本語' ? '戻る' : 'Back',
                          style: const TextStyle(
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
          ),
        ],
      ),
    );
  }

  void _next() async {
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == '日本語'
              ? '正しい形式のメールアドレスを入力してください。'
              : 'Please enter a valid email address.'),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _language == '日本語' ? 'パスワードが一致しません。' : 'Passwords do not match.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // FirebaseAuthを使って新規ユーザーを作成
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Firestoreにユーザー情報を保存
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'email': email,
        'language': _language,
      });

      // 次のページへ遷移
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SecondSignUpPage(userCredential: userCredential),
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == '日本語'
              ? 'エラーが発生しました: ${e.message}'
              : 'An error occurred: ${e.message}'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }
}
