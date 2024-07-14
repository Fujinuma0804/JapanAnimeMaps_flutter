import 'package:flutter/material.dart';

import 'data/web_page.dart';

class WebsiteScreen extends StatefulWidget {
  const WebsiteScreen({Key? key}) : super(key: key);

  @override
  State<WebsiteScreen> createState() => _WebsiteScreenState();
}

class _WebsiteScreenState extends State<WebsiteScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: WebPageHtml,
      ),
    );
  }
}
