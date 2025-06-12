import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class OfficialSiteScreen extends StatefulWidget {
  const OfficialSiteScreen({Key? key}) : super(key: key);

  @override
  State<OfficialSiteScreen> createState() => _OfficialSiteScreenState();
}

class _OfficialSiteScreenState extends State<OfficialSiteScreen> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // WebViewControllerの初期化
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // ローディングの進捗を更新
          },
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            // エラーハンドリング
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ページの読み込みに失敗しました'),
              ),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse('https://animetourism.co.jp'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          '公式サイト',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // 外部ブラウザで開くボタン（オプション）
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Color(0xFF00008b)),
            onPressed: () {
              launchUrl(Uri.parse('https://animetourism.co.jp'));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          // ローディングインジケーター
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00008b),
              ),
            ),
        ],
      ),
    );
  }
}