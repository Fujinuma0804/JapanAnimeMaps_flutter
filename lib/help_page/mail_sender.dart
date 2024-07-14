import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class MailScreen extends StatefulWidget {
  const MailScreen({Key? key}) : super(key: key);

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  late TextEditingController _bodyController;

  final String _to = 'initial_to@example.com';
  final String _cc = 'initial_cc@example.com';
  final String _bcc = 'initial_bcc@example.com';

  final List<String> _subjects = [
    '不具合について',
    'ポイントについて',
    '個人情報について',
    'ご意見・ご感想',
    'その他',
  ];

  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController();
    _selectedSubject = _subjects.first;
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
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
          )),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 40),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(hintText: '件名を選択してください'),
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
                controller: _bodyController,
                decoration: InputDecoration(hintText: '本文'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _sendEmail, child: Text('送信する')),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendEmail() async {
    final email = Email(
      body: _bodyController.text,
      subject: _selectedSubject ?? '',
      recipients: [_to],
      cc: [_cc],
      bcc: [_bcc],
      isHTML: false,
    );

    await FlutterEmailSender.send(email);
  }
}
