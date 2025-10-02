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
  bool _isProcessing = false;
  String _loadingMessage = '';
  bool _isScanning = false;
  bool _isFlashOn = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
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
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFF00008b),
              ),
              onPressed: () {
                if (!_isProcessing) {
                  Navigator.of(context).pop();
                }
              },
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Container(
                color: Colors.grey[300],
                height: 1.0,
              ),
            ),
          ),
          body: Container(
            color: Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 20.0),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'コードを入力してください',
                      errorText: _validateCode(_codeController.text),
                      labelStyle: const TextStyle(color: Color(0xFF00008b)),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF00008b)),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      errorBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: _isProcessing ||
                            _validateCode(_codeController.text) != null
                        ? null
                        : () => _processCode(_codeController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00008b),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'コードを確認',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _showQRScanner(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00008b),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'QRコードをスキャン',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 5,
                          blurRadius: 7,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00008b),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _loadingMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF00008b),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String? _validateCode(String value) {
    if (value.isEmpty) {
      return 'コードを入力してください';
    }
    if (value.length != 20) {
      return '20桁の数字を入力してください';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return '数字のみを入力してください';
    }
    return null;
  }

  void _showQRScanner() {
    if (_isProcessing) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: const Text(
              'QRコードをスキャン',
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFF00008b),
              ),
              onPressed: () {
                controller?.dispose();
                Navigator.of(context).pop();
              },
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: const Color(0xFF00008b),
                ),
                onPressed: () async {
                  await _toggleFlash();
                },
              ),
            ],
          ),
          body: QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: const Color(0xFF00008b),
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: MediaQuery.of(context).size.width * 0.8,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFlash() async {
    try {
      await controller?.toggleFlash();
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      _showMessage('フラッシュの切り替えに失敗しました');
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    _isScanning = false;

    controller.getFlashStatus().then((status) {
      if (mounted) {
        setState(() {
          _isFlashOn = status ?? false;
        });
      }
    });

    controller.scannedDataStream.listen(
      (scanData) async {
        if (scanData.code != null && !_isScanning) {
          _isScanning = true;

          try {
            await controller.pauseCamera();

            if (!mounted) return;

            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }

            await _processCode(scanData.code!);
          } catch (e) {
            debugPrint('QRスキャンエラー: $e');
            _showMessage('QRコードの読み取りに失敗しました');
          } finally {
            _isScanning = false;
            if (mounted) {
              controller.resumeCamera();
            }
          }
        }
      },
      onError: (error) {
        debugPrint('QRスキャンエラー: $error');
        _showMessage('QRコードの読み取りに失敗しました');
      },
    );
  }

  Future<void> _processCode(String code) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _loadingMessage = 'コードを確認中...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('ログインしていません');
        return;
      }

      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('codes')
          .where('code', isEqualTo: code)
          .limit(1)
          .get(const GetOptions(source: Source.server));

      if (!mounted) return;

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        final usageLimit = data['usageLimit'] ?? 1;
        final usageCount = data['usageCount'] ?? 0;
        final List<dynamic> usedBy = data['usedBy'] ?? [];

        if (usedBy.contains(user.email)) {
          _showMessage('このコードは既に使用済みです');
          return;
        }

        if (usageLimit == -1 || usageCount < usageLimit) {
          _showConfirmationDialog(code, data['points'] ?? 0);
        } else {
          _showMessage('このコードは使用上限に達しています');
        }
      } else {
        _showMessage('無効なコードです');
      }
    } catch (e) {
      _showMessage('エラーが発生しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _loadingMessage = '';
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showConfirmationDialog(String code, int points) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'QRコードスキャン',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text('$codeがスキャンされました。\n$pointsポイントを追加しますか？'),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'いいえ',
                style: TextStyle(color: Color(0xFF00008b)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'はい',
                style: TextStyle(color: Color(0xFF00008b)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _addPoints(code, points);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addPoints(String code, int points) async {
    setState(() {
      _isProcessing = true;
      _loadingMessage = 'ポイントを追加中...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('ログインしていません');
        return;
      }

      final db = FirebaseFirestore.instance;

      final QuerySnapshot codeSnapshot = await db
          .collection('codes')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (codeSnapshot.docs.isEmpty) {
        throw Exception('コードが見つかりません');
      }

      final codeDocRef = codeSnapshot.docs.first.reference;
      final userRef = db.collection('users').doc(user.uid);

      await db.runTransaction((transaction) async {
        final codeDoc = await transaction.get(codeDocRef);
        final userDoc = await transaction.get(userRef);

        if (!codeDoc.exists) {
          throw Exception('コードが見つかりません');
        }

        final codeData = codeDoc.data() as Map<String, dynamic>;

        final usageLimit = codeData['usageLimit'] ?? 1;
        final usageCount = codeData['usageCount'] ?? 0;
        final List<dynamic> usedBy = codeData['usedBy'] ?? [];

        if (usedBy.contains(user.email)) {
          throw Exception('既に使用済みです');
        }

        if (usageLimit != -1 && usageCount >= usageLimit) {
          throw Exception('使用制限を超えています');
        }

        transaction.update(codeDocRef, {
          'usageCount': usageCount + 1,
          'usedBy': [...usedBy, user.email],
          'usedAt': FieldValue.arrayUnion([Timestamp.now()]),
        });

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final currentPoints = userData['Point'] ?? 0;
          transaction.update(userRef, {'Point': currentPoints + points});
        } else {
          transaction.set(userRef, {'Point': points});
        }
      });

      if (mounted) {
        _showMessage('$pointsポイントが追加されました');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoadingCodeTop()),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        _showMessage('ポイントの追加に失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _loadingMessage = '';
        });
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    _codeController.dispose();
    super.dispose();
  }
}
