import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:parts/login_page/login_page.dart';

class SecondSignUpPage extends StatefulWidget {
  final UserCredential userCredential;

  const SecondSignUpPage({Key? key, required this.userCredential})
      : super(key: key);

  @override
  State<SecondSignUpPage> createState() => _SecondSignUpPageState();
}

class _SecondSignUpPageState extends State<SecondSignUpPage> {
  final _firestore = FirebaseFirestore.instance;

  String userName = '';
  String name = '';
  String id = '';
  DateTime? selectedDate;

  bool _isLoading = false;
  String _language = '日本語';

  @override
  void initState() {
    super.initState();
    _loadUserLanguage();
  }

  void _loadUserLanguage() async {
    DocumentSnapshot userDoc = await _firestore
        .collection('users')
        .doc(widget.userCredential.user?.uid)
        .get();

    if (userDoc.exists && userDoc['language'] != null) {
      setState(() {
        _language = userDoc['language'];
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate)
      setState(() {
        selectedDate = picked;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _language == '日本語' ? '追加情報を登録' : 'Sign Up Additional Info',
          style: const TextStyle(
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
                          id = value;
                        },
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText: _language == '日本語'
                              ? 'ユーザーIDを入力'
                              : 'Enter User ID',
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
                          name = value;
                        },
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              _language == '日本語' ? '名前を入力' : 'Enter Your Name',
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
                      child: GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: _language == '日本語'
                                  ? '誕生日を選択'
                                  : 'Select Birthday',
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
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.left,
                            controller: TextEditingController(
                              text: selectedDate == null
                                  ? ''
                                  : DateFormat('yyyy-MM-dd')
                                      .format(selectedDate!),
                            ),
                          ),
                        ),
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
                              _language == '日本語' ? '登録' : 'Sign Up',
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
        ],
      ),
    );
  }

  void _next() async {
    if (id.isEmpty || name.isEmpty || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == '日本語'
              ? '全てのフィールドを入力してください。'
              : 'Please fill in all fields.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Firestoreに追加情報を保存
      await _firestore
          .collection('users')
          .doc(widget.userCredential.user?.uid)
          .update({
        'name': name,
        'id': id,
        'birthday': selectedDate,
        'created_at': FieldValue.serverTimestamp(), // 作成日時を追加
      });

      // 登録完了メッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == '日本語'
              ? '登録が完了しました。'
              : 'Registration completed successfully.'),
        ),
      );

      // ログインページへ遷移
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _language == '日本語' ? 'エラーが発生しました: $e' : 'An error occurred: $e'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
