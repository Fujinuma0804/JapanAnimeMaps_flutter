import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class QA extends StatefulWidget {
  const QA({Key? key}) : super(key: key);

  @override
  State<QA> createState() => _WebsiteScreenState();
}

class _WebsiteScreenState extends State<QA>
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
      ..loadRequest(
          Uri.parse('https://infomapanime.click/home_q_a/?page_id=6'));

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..forward();

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
        appBar: AppBar(
          title: Text(
            '',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
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
