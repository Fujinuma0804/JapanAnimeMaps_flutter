import 'dart:async';
import 'dart:typed_data'; // Uint8Listのために追加

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeFeedbackWidget extends StatefulWidget {
  final Widget child;

  const ShakeFeedbackWidget({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<ShakeFeedbackWidget> createState() => _ShakeFeedbackWidgetState();
}

class _ShakeFeedbackWidgetState extends State<ShakeFeedbackWidget> {
  static const double _shakeThreshold = 10.0;
  static const Duration _cooldownDuration = Duration(seconds: 1);

  DateTime? _lastShakeTime;
  StreamSubscription? _subscription;
  final _screenshotController = ScreenshotController();
  Uint8List? _screenshotData;

  @override
  void initState() {
    super.initState();
    _initShakeDetection();
  }

  void _initShakeDetection() {
    _subscription = accelerometerEvents.listen((AccelerometerEvent event) {
      double acceleration =
          event.x * event.x + event.y * event.y + event.z * event.z;

      if (acceleration > _shakeThreshold) {
        final now = DateTime.now();
        if (_lastShakeTime == null ||
            now.difference(_lastShakeTime!) > _cooldownDuration) {
          _lastShakeTime = now;
          _handleShake();
        }
      }
    });
  }

  Future<void> _handleShake() async {
    // スクリーンショットを取得
    final screenshot = await _screenshotController.capture();
    if (screenshot != null) {
      setState(() {
        _screenshotData = screenshot;
      });
    }

    if (!mounted) return;

    // ボトムシートを表示
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildBottomSheet(),
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '技術的な問題を報告',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '機能または製品が正しく機能していない場合、JapanAnimeMapsの改善のためフィードバックを送信できます。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: 問題を報告する処理を実装
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white, // foregroundをforegroundColorに修正
              ),
              child: const Text('問題を報告'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('ここでは不正利用またはスパムに関する報告は送信しないでください。'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 不正利用報告についての詳細画面への遷移を実装
            },
          ),
          SwitchListTile(
            title: const Text('携帯電話をシェイクして問題を報告'),
            subtitle: const Text('切り替えて無効にできます'),
            value: true, // TODO: 設定値と連動させる
            onChanged: (bool value) {
              // TODO: シェイク検知の有効/無効を切り替える処理を実装
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: _screenshotController,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
