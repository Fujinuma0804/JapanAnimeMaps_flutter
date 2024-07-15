import 'package:flutter/material.dart';

import 'admin_notices.dart';
import 'contacts_notices.dart';
import 'important_notices.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'お知らせ',
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
          bottom: const TabBar(
            tabs: [
              Tab(text: '重要なお知らせ'),
              Tab(text: '運営からのお知らせ'),
              Tab(text: 'お問い合わせ'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ImportantNoticesTab(),
            AdminNoticesTab(),
            ContactUsTab(),
          ],
        ),
      ),
    );
  }
}
