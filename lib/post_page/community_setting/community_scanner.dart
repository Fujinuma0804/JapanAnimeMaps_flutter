import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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

  // Hot Reload時の処理のために必要
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  void _handleScannedData(String scannedData) {
    if (isProcessing) return;

    try {
      isProcessing = true;
      final Map<String, dynamic> data = json.decode(scannedData);

      // 招待データの検証
      if (data['type'] == 'invitation' && data['app'] == 'partsbox') {
        final inviteCode = data['code'];

        // スキャン成功時のフィードバック
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('招待コード: $inviteCode を読み取りました'),
            backgroundColor: Colors.green,
          ),
        );

        // スキャン画面を閉じて前の画面に戻る
        Navigator.pop(context, inviteCode);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('無効なQRコードです'),
            backgroundColor: Colors.red,
          ),
        );
        // 1秒後に再スキャンを有効にする
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              isProcessing = false;
            });
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QRコードの読み取りに失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error processing QR code data: $e');
      // 1秒後に再スキャンを有効にする
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            isProcessing = false;
          });
        }
      });
    }
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
          // ライトの切り替えボタン
          IconButton(
            icon: const Icon(
              Icons.flash_on,
              color: Color(0xFF00008b),
            ),
            onPressed: () async {
              await controller?.toggleFlash();
            },
          ),
          // カメラ切り替えボタン
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
                // 追加のガイド表示（オプション）
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
