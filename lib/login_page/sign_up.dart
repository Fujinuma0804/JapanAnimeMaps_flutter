import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:parts/login_page/mail_sign_up2.dart';
import 'package:parts/login_page/welcome_page/welcome_1.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../src/page_route.dart';
import '../src/bottomnavigationbar.dart';
import 'login_page.dart';
import 'mail_sign_up1.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
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

      QuerySnapshot existingUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userCredential.user?.email)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => Welcome1()
              // MainScreen(),
              ),
        );
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user?.uid)
            .set({
          'email': userCredential.user?.email,
          'language': 'Japanese',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('サインインに失敗しました。もう一度お試しください。')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      final AuthorizationCredentialAppleID credential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final authCredential = oAuthProvider.credential(
        idToken: credential.identityToken,
        rawNonce: rawNonce,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(authCredential);

      // ここから先は元のコードと同じ
      QuerySnapshot existingUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userCredential.user?.email)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainScreen(),
          ),
        );
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user?.uid)
            .set({
          'email': userCredential.user?.email,
          'language': 'Japanese',
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
      print('Error signing in with Apple: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appleでのサインインに失敗しました。もう一度お試しください。')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInAnonymously();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user?.uid)
          .set({
        'isGuest': true,
        'language': 'Japanese',
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    } catch (e) {
      print('Error signing in anonymously: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ゲストログインに失敗しました。もう一度お試しください。'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showGuestWarningDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // ダイアログ外をタップしても閉じないようにする
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'ゲスト利用の注意',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('ゲストとして利用する場合、以下の制限があります：'),
                SizedBox(height: 10),
                Text('• データは端末に保存されません'),
                Text('※ 30日が経過するとデータは削除されます。'),
                Text('• アカウントやデータの復元はできません'),
                Text('• 一部の機能が制限される可能性があります'),
                Text('• チェックインをされてもポイントはお貯めいただけません'),
                SizedBox(height: 10),
                Text('続行されますか？'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'キャンセル',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                '続行',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _signInAnonymously();
              },
            ),
          ],
        );
      },
    );
  }

  String generateNonce([int length = 32]) {
    final charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/login.png',
                  fit: BoxFit.cover,
                ),
              ),
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
                            elasticTransition(const MailSignUpPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: const Text(
                          'メールアドレスで登録',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    SizedBox(
                      width: 300.0,
                      height: 50.0,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: const Text(
                          'Googleで登録',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    SizedBox(
                      width: 300.0,
                      height: 50.0,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signInWithApple,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: const Text(
                          'Appleで登録',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    SizedBox(
                      width: 300.0,
                      height: 50.0,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _showGuestWarningDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: const Text(
                          'ゲストで利用',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          elasticTransition(const LoginPage()),
                        );
                      },
                      child: const Text(
                        'ログインはこちら',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ));
  }
}
