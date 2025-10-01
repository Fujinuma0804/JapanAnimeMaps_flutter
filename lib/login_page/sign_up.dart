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

class _SignUpPageState extends State<SignUpPage> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isLoading = false;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  final List<AnimationController> _letterControllers = [];
  final List<Animation<double>> _letterAnimations = [];
  bool _titleVisible = false;
  final String titleText = 'JapanAnimeMaps';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    for (int i = 0; i < titleText.length; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );
      _letterControllers.add(controller);
      _letterAnimations.add(
        Tween<double>(begin: 0, end: -10)
            .chain(CurveTween(curve: Curves.easeInOut))
            .animate(controller),
      );
    }

    _controller.forward().then((_) {
      setState(() {
        _titleVisible = true;
      });
      _startLetterAnimations();
    });
  }

  void _startLetterAnimations() {
    for (var i = 0; i < _letterControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _letterControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var controller in _letterControllers) {
      controller.dispose();
    }
    super.dispose();
  }

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
        accessToken: credential.authorizationCode
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(authCredential);

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
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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
        });
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

  // [前のコードと同じ部分は変更なし]

  Widget _buildSignInButton({
    required String text,
    required VoidCallback onPressed,
    required Widget icon,
    bool isDisabled = false,
    bool isGoogle = false,
    bool isApple = false,
    bool isGuest = false,
  }) {
    return Container(
      width: 350.0,
      height: 50.0,
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isGoogle
              ? Colors.white
              : isApple
                  ? Colors.black
                  : isGuest
                      ? Colors.grey.shade200
                      : const Color(0xFF7986CB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: isGoogle
                ? BorderSide(color: Colors.grey.shade300)
                : BorderSide.none,
          ),
          elevation: 3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 50,
              child: Center(
                child: icon is Icon
                    ? Icon(
                        icon.icon,
                        color: isGuest ? Colors.grey.shade700 : icon.color,
                        size: icon.size,
                      )
                    : icon,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: 50),
                child: Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isGoogle
                          ? Colors.black
                          : isGuest
                              ? Colors.grey.shade700
                              : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SlideTransition(
                          position: _slideAnimation,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < titleText.length; i++)
                                if (_titleVisible)
                                  AnimatedBuilder(
                                    animation: _letterAnimations[i],
                                    builder: (context, child) {
                                      return Transform.translate(
                                        offset: Offset(
                                            0, _letterAnimations[i].value),
                                        child: Text(
                                          titleText[i],
                                          style: TextStyle(
                                            color: Color(0xFF00008b),
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                else
                                  Container(),
                            ],
                          ),
                        ),
                        SizedBox(height: 60),
                        SizedBox(height: 40),
                        _buildSignInButton(
                          text: 'メールアドレスで登録',
                          onPressed: () {
                            Navigator.of(context).push(
                              elasticTransition(const MailSignUpPage()),
                            );
                          },
                          icon: Icon(Icons.mail, color: Colors.white),
                        ),
                        _buildSignInButton(
                          text: 'Googleで会員登録',
                          onPressed: _signInWithGoogle,
                          icon: Image.asset(
                            'assets/icon/google_logo.png',
                            width: 24,
                            height: 24,
                          ),
                          isDisabled: _isLoading,
                          isGoogle: true,
                        ),
                        _buildSignInButton(
                          text: 'Appleで会員登録',
                          onPressed: _signInWithApple,
                          icon: Icon(Icons.apple, color: Colors.white),
                          isDisabled: _isLoading,
                          isApple: true,
                        ),
                        _buildSignInButton(
                          text: 'ゲストで利用',
                          onPressed: _showGuestWarningDialog,
                          icon: Icon(Icons.person_outline, color: Colors.white),
                          isDisabled: _isLoading,
                          isGuest: true,
                        ),
                        SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              elasticTransition(const LoginPage()),
                            );
                          },
                          child: Text(
                            'ログインはこちら',
                            style: TextStyle(
                              color: Colors.black,
                              decoration: TextDecoration.underline,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
