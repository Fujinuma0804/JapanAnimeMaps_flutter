import 'package:flutter/material.dart';

class WebsiteScreen extends StatefulWidget {
  const WebsiteScreen({Key? key}) : super(key: key);

  @override
  State<WebsiteScreen> createState() => _WebsiteScreenState();
}

class _WebsiteScreenState extends State<WebsiteScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(
        child: Column(
          children: [
            Text(
              'This is WebSite',
            ),
          ],
        ),
      ),
    );
  }
}
