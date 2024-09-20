import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportScreen extends StatefulWidget {
  final String animeName;

  const ReportScreen({Key? key, required this.animeName}) : super(key: key);

  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late TextEditingController _animeNameController;
  late TextEditingController _emailController;
  late TextEditingController _contentController;
  bool _sendUpdates = false;

  @override
  void initState() {
    super.initState();
    _animeNameController = TextEditingController(text: widget.animeName);
    _emailController = TextEditingController();
    _contentController = TextEditingController();
    _getUserEmail();
  }

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

  Future<void> _submitReport() async {
    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'animeName': _animeNameController.text,
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
        title: Text('フィードバックを送信'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _submitReport,
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
            _buildTextField('アニメ名:', _animeNameController, enabled: false),
            SizedBox(height: 16),
            Text(
                'ご意見をお待ちしています。機密情報は含めないでください。\n'
                'ご質問や法的な問題は、ヘルプまたはサポートをご利用ください。',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: '本文を入力してください',
              ),
            ),
            SizedBox(height: 16),
            Row(
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
                  child: Text('詳細や最新情報に関するメールをお送りさせていただく場合があります',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
                'アカウントとシステムに関する情報の一部が送信されることがあります。この情報は、プライバシーポリシーおよび利用規約に従って、問題の修正やサービスの改善のために使用します。法的な理由によりコンテンツの変更をリクエストするには、お問い合わせよりご連絡ください。',
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
    _animeNameController.dispose();
    _emailController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
