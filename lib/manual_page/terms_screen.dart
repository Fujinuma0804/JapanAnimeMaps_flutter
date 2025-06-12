import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({Key? key}) : super(key: key);

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
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
      ..loadRequest(Uri.parse('https://animetourism.co.jp/terms'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          '利用規約',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
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