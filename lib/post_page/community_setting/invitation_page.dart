import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class InvitationPage extends StatefulWidget {
  final String communityId;
  const InvitationPage({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  @override
  State<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends State<InvitationPage> {
  String invitationCode = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey _shareContentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _getOrGenerateInvitationCode();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return String.fromCharCodes(Iterable.generate(
        5, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> _getOrGenerateInvitationCode() async {
    try {
      // community_list コレクションから該当のコミュニティドキュメントを参照
      final docRef =
          _firestore.collection('community_list').doc(widget.communityId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists && docSnapshot.data()?['invitationCode'] != null) {
        setState(() {
          invitationCode = docSnapshot.data()!['invitationCode'];
        });
      } else {
        String newCode = _generateCode();
        // コミュニティドキュメントを更新
        await docRef.update({
          'invitationCode': newCode,
          'invitationCodeCreatedAt': FieldValue.serverTimestamp(),
          'invitationCodeIsActive': true,
        });
        setState(() {
          invitationCode = newCode;
        });
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _shareInvitationCode() async {
    try {
      final RenderRepaintBoundary boundary = _shareContentKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/invitation.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'PartsBoxの招待コード',
        subject: 'PartsBoxへの招待',
      );
    } catch (e) {
      print('Error sharing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrData = json.encode({
      'type': 'invitation',
      'code': invitationCode,
      'app': 'partsbox',
      'communityId': widget.communityId,
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF000080),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '招待',
          style: TextStyle(
            color: Color(0xFF000080),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              RepaintBoundary(
                key: _shareContentKey,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 250,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      '招待コード',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        invitationCode.split('').join(' '),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              const Center(
                child: Text(
                  'シェアをするとQRコードと招待コードが共有されます。',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _shareInvitationCode,
                  icon: const Icon(Icons.share),
                  label: const Text('招待コードをシェア'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF000080),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
