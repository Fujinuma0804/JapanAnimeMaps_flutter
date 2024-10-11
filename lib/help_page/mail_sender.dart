import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class MailScreen extends StatefulWidget {
  const MailScreen({Key? key}) : super(key: key);

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  late TextEditingController _bodyController;
  late TextEditingController _contactEmailController;
  String _registeredEmail = '';

  final String _to = 'japananimemaps@gmail.com';
  final String _cc = '';
  final String _bcc = '';

  final List<String> _subjects = [
    '不具合について',
    'ポイントについて',
    '個人情報について',
    'ご要望',
    'ご意見・ご感想',
    'その他',
  ];

  String? _selectedSubject;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController();
    _contactEmailController = TextEditingController();
    _selectedSubject = _subjects.first;
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _registeredEmail = userDoc.get('email') as String? ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading user email: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  bool _isEmailValid(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _canSendEmail() {
    return _bodyController.text.isNotEmpty &&
        (_contactEmailController.text.isEmpty ||
            _isEmailValid(_contactEmailController.text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'メール送信',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: '件名を選択してください'),
                        value: _selectedSubject,
                        items: _subjects.map((String subject) {
                          return DropdownMenuItem<String>(
                            value: subject,
                            child: Text(subject),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedSubject = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        initialValue: _registeredEmail,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: '登録アドレス',
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _contactEmailController,
                        decoration: InputDecoration(
                          labelText: '連絡先アドレス',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null &&
                              value.isNotEmpty &&
                              !_isEmailValid(value)) {
                            return '有効なメールアドレスを入力してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _bodyController,
                        decoration: InputDecoration(labelText: '本文'),
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '本文を入力してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _canSendEmail() ? _sendEmail : null,
                        child: Text('送信する'),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _sendEmail() async {
    if (_formKey.currentState!.validate()) {
      final email = Email(
        body: '''
【問い合わせ内容】
件名：${_selectedSubject}
登録アドレス：${_registeredEmail}
連絡先アドレス：${_contactEmailController.text}
本文：${_bodyController.text}
''',
        subject: _selectedSubject ?? '',
        recipients: [_to],
        cc: [_cc],
        bcc: [_bcc],
        isHTML: false,
      );

      await FlutterEmailSender.send(email);
    }
  }
}
