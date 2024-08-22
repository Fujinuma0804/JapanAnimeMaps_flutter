import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'chat_detail.dart';

class ChatHistoryPage extends StatelessWidget {
  final String userId;

  const ChatHistoryPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'チャット履歴',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chatHistories')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null || !data.containsKey('history')) {
            return Center(child: Text('チャット履歴がありません'));
          }

          final chatHistory = (data['history'] as List<dynamic>)
              .map((item) => item as Map<String, dynamic>)
              .toList();

          return ListView.builder(
            itemCount: chatHistory.length,
            itemBuilder: (context, index) {
              final session = chatHistory[index];
              final date =
                  DateTime.fromMillisecondsSinceEpoch(session['lastUpdated']);
              return ListTile(
                title: Text('管理番号: ${session['managementNumber']}'),
                subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(date)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailPage(
                        userId: userId,
                        managementNumber: session['managementNumber'],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
