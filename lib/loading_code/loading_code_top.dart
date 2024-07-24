import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class LoadingCodeTop extends StatefulWidget {
  const LoadingCodeTop({Key? key}) : super(key: key);

  @override
  State<LoadingCodeTop> createState() => _LoadingCodeTopState();
}

class _LoadingCodeTopState extends State<LoadingCodeTop> {
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'コード読み込み',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'コードを入力してください',
                errorText: _validateCode(_codeController.text),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          ElevatedButton(
            onPressed: _validateCode(_codeController.text) == null
                ? () => _processCode(_codeController.text)
                : null,
            child: const Text('コードを確認'),
          ),
          ElevatedButton(
            onPressed: () => _showQRScanner(),
            child: const Text('QRコードをスキャン'),
          ),
        ],
      ),
    );
  }

  String? _validateCode(String value) {
    if (value.length != 20) {
      return '20桁の数字を入力してください';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return '数字のみを入力してください';
    }
    return null;
  }

  void _processCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしていません')),
      );
      return;
    }

    final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('codes')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final docRef = querySnapshot.docs.first.reference;
      final data = querySnapshot.docs.first.data() as Map<String, dynamic>;

      if (data['isUsed'] == false) {
        // Update the code document
        await docRef.update({
          'isUsed': true,
          'usedAt': FieldValue.serverTimestamp(),
          'usedBy': user.email,
        });

        // Update user's correctCount
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          int currentCorrectCount = userDoc.data()?['correctCount'] ?? 0;
          int pointsToAdd = data['points'] ?? 0;
          await userDoc.reference.update({
            'correctCount': currentCorrectCount + pointsToAdd,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('コードが正常に処理されました。${data['points']}ポイント追加されました。')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('このコードは既に使用されています')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無効なコードです')),
      );
    }
  }

  void _showQRScanner() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('QRコードをスキャン'),
        ),
        body: QRView(
          key: qrKey,
          onQRViewCreated: _onQRViewCreated,
        ),
      ),
    ));
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        setState(() {
          _codeController.text = scanData.code!;
        });
        Navigator.of(context).pop(); // QRスキャン画面を閉じる
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
