import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart'; // 追加
import 'package:webview_flutter/webview_flutter.dart';

class WebsiteScreen extends StatefulWidget {
  const WebsiteScreen({Key? key}) : super(key: key);

  @override
  State<WebsiteScreen> createState() => _WebsiteScreenState();
}

class _WebsiteScreenState extends State<WebsiteScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController controller;
  bool _isLoading = true;
  late AnimationController _animationController;
  final List<String> _loadingText = "Loading".split('');

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://testtestaaaa.my.canva.site/home'));

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..forward();

    // バイブレーションを追加
    if (Vibration.hasVibrator() != null) {
      Vibration.vibrate(duration: 500);
    }

    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (_isLoading)
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_loadingText.length, (index) {
                          return AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              double t = ((_animationController.value -
                                          index / _loadingText.length) *
                                      _loadingText.length)
                                  .clamp(0.0, 1.0);
                              return Transform.translate(
                                offset: Offset(
                                    0,
                                    -100 *
                                        (1 - Curves.easeOutBack.transform(t))),
                                child: Text(
                                  _loadingText[index],
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 24),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                      SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Container(
                            width: 200 * _animationController.value,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
