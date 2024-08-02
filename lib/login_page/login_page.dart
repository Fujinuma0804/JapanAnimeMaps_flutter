import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:parts/login_page/sign_up.dart';

import '../../src/page_route.dart';
import '../src/bottomnavigationbar.dart';
import 'mail_login.dart';
import 'mail_sign_up2.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // ユーザーがサインインをキャンセルした場合
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // Firestoreで同じメールアドレスのユーザーを検索
      QuerySnapshot existingUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userCredential.user?.email)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        // 既存のユーザーが見つかった場合
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainScreen(),
          ),
        );
      } else {
        // 新規ユーザーの場合
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user?.uid)
            .set({
          'email': userCredential.user?.email,
          'language': '日本語', // or set this based on user choice if applicable
        });

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SecondSignUpPage(
              userCredential: userCredential,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      // エラーが発生した場合、ユーザーに通知することをお勧めします
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('サインインに失敗しました。もう一度お試しください。')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(
                        color: Colors.white, //枠線
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
                      'Appleでログイン',
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
