import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:parts/post_page/community_list_detail.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({Key? key}) : super(key: key);

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isProcessing = false;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  Future<Map<String, dynamic>?> _fetchCommunityData(String inviteCode) async {
    try {
      // Firebaseのcommunity_listコレクションを参照
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('community_list')
          .where('invitationCode', isEqualTo: inviteCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      // ドキュメントのデータを取得
      return querySnapshot.docs.first.data() as Map<String, dynamic>;
    } catch (e) {
      print('Error fetching community data: $e');
      return null;
    }
  }

  void _handleScannedData(String scannedData) async {
    if (isProcessing) return;

    try {
      isProcessing = true;
      final Map<String, dynamic> data = json.decode(scannedData);

      if (data['type'] == 'invitation' && data['app'] == 'partsbox') {
        final inviteCode = data['code'];

        // Firebaseからコミュニティデータを取得
        final communityData = await _fetchCommunityData(inviteCode);

        if (communityData != null) {
          if (!mounted) return;

          // スキャン成功時のフィードバック
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('コミュニティが見つかりました: ${communityData['name']}'),
              backgroundColor: Colors.green,
            ),
          );

          // 取得したコミュニティデータを使用してCommunityDetailScreenへ遷移
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityDetailScreen(
                community: communityData,
              ),
            ),
          );
        } else {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('無効な招待コードです'),
              backgroundColor: Colors.red,
            ),
          );
          _resetProcessingState();
        }
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('無効なQRコードです'),
            backgroundColor: Colors.red,
          ),
        );
        _resetProcessingState();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QRコードの読み取りに失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error processing QR code data: $e');
      _resetProcessingState();
    }
  }

  void _resetProcessingState() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    });
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        _handleScannedData(scanData.code!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF00008b),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'QRコードをスキャン',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.flash_on,
              color: Color(0xFF00008b),
            ),
            onPressed: () async {
              await controller?.toggleFlash();
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.cameraswitch,
              color: Color(0xFF00008b),
            ),
            onPressed: () async {
              await controller?.flipCamera();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Colors.white,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: 250,
                  ),
                ),
                Positioned(
                  bottom: 50,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'QRコードをフレーム内に配置してください',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
