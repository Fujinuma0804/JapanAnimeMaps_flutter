import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../src/bottomnavigationbar.dart';

class SecondSignUpPage extends StatefulWidget {
  final String email;
  final String password;

  const SecondSignUpPage(
      {required this.email, required this.password, Key? key})
      : super(key: key);

  @override
  State<SecondSignUpPage> createState() => _SecondSignUpPageState();
}

class _SecondSignUpPageState extends State<SecondSignUpPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String name = '';
  String id = '';
  String birthday = '';

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '登録情報を入力',
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
              'assets/images/star.jpg',
              fit: BoxFit.cover,
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (BuildContext context, ScrollController scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: Padding(
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
                              name = value;
                            },
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration(
                              labelText: '名前を入力',
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
                              id = value.toLowerCase(); // 小文字に変換して代入
                            },
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'IDを入力（小文字と数字のみ）',
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
                              birthday = value;
                            },
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration(
                              labelText: '誕生日を入力',
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
                          onPressed: _isLoading ? null : _signUp,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
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
                      const SizedBox(height: 35.0),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _signUp() async {
    // 正規表現パターン: 小文字アルファベットと数字のみを許可する
    final RegExp idPattern = RegExp(r'^[a-z0-9]+$');

    // IDがパターンに一致するかチェック
    if (!idPattern.hasMatch(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('IDは小文字アルファベットと数字のみ使用できます。'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // FirestoreでIDの重複をチェック
      final idExists = await _firestore
          .collection('users')
          .where('id', isEqualTo: id)
          .limit(1)
          .get();

      if (idExists.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('このIDは既に使用されています。別のIDをお試しください。'),
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Firebase Authでユーザを登録
      final newUser = await _auth.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      if (newUser != null) {
        // Firestoreにユーザ情報を保存
        await _firestore.collection('users').doc(newUser.user?.uid).set({
          'name': name,
          'id': id,
          'email': widget.email,
          'birthday': birthday,
          'created_at': FieldValue.serverTimestamp(),
        });

        // メイン画面に遷移
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
      print('Error code: ${e.code}');
      print('Error message: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
        ),
      );
    } catch (e) {
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
