import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PointsFeedbackScreen extends StatefulWidget {
  const PointsFeedbackScreen({Key? key}) : super(key: key);

  @override
  _PointsFeedbackScreenState createState() => _PointsFeedbackScreenState();
}

class _PointsFeedbackScreenState extends State<PointsFeedbackScreen> {
  late TextEditingController _emailController;
  late TextEditingController _contentController;
  bool _sendUpdates = false;
  bool _isContentValid = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _contentController = TextEditingController();
    _contentController.addListener(_validateContent);
    _getUserEmail();
  }

  void _validateContent() {
    setState(() {
      _isContentValid = _contentController.text.trim().isNotEmpty;
    });
  }

  bool get _isFormValid => _isContentValid && _sendUpdates;

  Future<void> _getUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      setState(() {
        _emailController.text = user.email!;
      });
    } else {
      setState(() {
        _emailController.text = 'Not signed in';
      });
    }
  }

  Future<void> _submitFeedback() async {
    if (!_isFormValid) {
      String errorMessage = '';
      if (!_isContentValid) {
        errorMessage = 'フィードバックの内容を入力してください';
      } else if (!_sendUpdates) {
        errorMessage = '最新情報の受け取りに同意してください';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('points_feedback').add({
        'email': _emailController.text,
        'content': _contentController.text,
        'sendUpdates': _sendUpdates,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('フィードバックが送信されました')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'フィードバック',
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.send,
                color: _isFormValid ? Colors.black : Colors.grey),
            onPressed: _isFormValid ? _submitFeedback : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField('差出人:', _emailController, enabled: false),
            SizedBox(height: 16),
            Text(
                'ポイントシステムについてのご意見をお待ちしています。\n'
                'ご質問や法的な問題は、ヘルプまたはサポートをご利用ください。',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'ポイントについてのご意見を入力してください',
                errorText: _contentController.text.isEmpty
                    ? 'フィードバックの内容を入力してください'
                    : null,
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _sendUpdates ? Colors.transparent : Colors.red,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _sendUpdates,
                    onChanged: (bool? value) {
                      setState(() {
                        _sendUpdates = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      '詳細や最新情報に関するメールをお送りさせていただく場合があります',
                      style: TextStyle(
                        fontSize: 12,
                        color: _sendUpdates ? Colors.black : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_sendUpdates) ...[
              SizedBox(height: 4),
              Text(
                '同意が必要です',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
            SizedBox(height: 16),
            Text(
                'アカウントとシステムに関する情報の一部が送信されることがあります。この情報は、プライバシーポリシーおよび利用規約に従って、問題の修正やサービスの改善のために使用します。',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        filled: !enabled,
        fillColor: !enabled ? Colors.grey[200] : null,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
