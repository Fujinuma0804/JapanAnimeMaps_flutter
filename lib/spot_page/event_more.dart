import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html_unescape/html_unescape.dart';
import 'package:url_launcher/url_launcher.dart';

class EventMoreScreen extends StatelessWidget {
  final String eventTitle;
  final String startDate;
  final String htmlContent;

  EventMoreScreen({
    Key? key,
    required this.eventTitle,
    required this.startDate,
    required this.htmlContent,
  }) : super(key: key) {
    developer.log('EventMoreScreen Constructor:', error: {
      'eventTitle': eventTitle,
      'startDate': startDate,
      'htmlContent': htmlContent,
    });
  }

  @override
  Widget build(BuildContext context) {
    developer.log('EventMoreScreen build started');

    final unescape = HtmlUnescape();
    final unescapedContent = unescape.convert(htmlContent);

    developer.log('Unescaped HTML content:', error: unescapedContent);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          eventTitle,
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Color(0xFF00008b)),
          onPressed: () {
            developer.log('Back button pressed');
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(builder: (context) {
                developer.log('Rendering HTML content');
                return Html(
                  data: unescapedContent,
                  style: {
                    "body": Style(
                      padding: HtmlPaddings.zero,
                      margin: Margins.zero,
                    ),
                    "p": Style(
                      fontSize: FontSize(16.0),
                      lineHeight: LineHeight(1.5),
                      margin: Margins.only(bottom: 10),
                    ),
                    "h1": Style(
                      fontSize: FontSize(24.0),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(bottom: 16, top: 16),
                    ),
                    "h2": Style(
                      fontSize: FontSize(20.0),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(bottom: 12, top: 12),
                    ),
                    "img": Style(
                      width: Width(MediaQuery.of(context).size.width - 32),
                      margin: Margins.only(top: 8, bottom: 8),
                    ),
                    "a": Style(
                      color: Colors.blue,
                      textDecoration: TextDecoration.underline,
                    ),
                    "table": Style(
                      border: Border.all(color: Colors.grey),
                      margin: Margins.only(top: 8, bottom: 8),
                    ),
                    "tr": Style(
                      border: Border.all(color: Colors.grey),
                    ),
                    "td": Style(
                      padding: HtmlPaddings.all(8),
                      border: Border.all(color: Colors.grey),
                    ),
                  },
                  onLinkTap: (String? url, Map<String, String> attributes,
                      dom.Element? element) async {
                    developer.log('HTML link tapped:', error: url ?? 'null');
                    if (url != null) {
                      final Uri uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
