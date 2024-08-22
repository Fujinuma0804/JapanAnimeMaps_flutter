import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:intl/intl.dart';

class ChatDetailPage extends StatelessWidget {
  final String userId;
  final String managementNumber;
  final bool isInputEnabled; // A flag to control input availability

  const ChatDetailPage({
    Key? key,
    required this.userId,
    required this.managementNumber,
    this.isInputEnabled = false, // Set to false to disable input
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'チャット詳細',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('chatSessions')
            .doc(managementNumber)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final sessionData = snapshot.data!.data() as Map<String, dynamic>?;
          if (sessionData == null) {
            return Center(child: Text('セッションが見つかりません'));
          }

          final chatHistory = (sessionData['history'] as List<dynamic>)
              .map((item) => types.TextMessage(
                    author: types.User(id: item['authorId']),
                    createdAt: item['createdAt'],
                    id: item['id'] ?? '',
                    text: item['text'],
                  ))
              .toList();

          return Column(
            children: [
              Expanded(
                child: Chat(
                  messages: chatHistory,
                  onSendPressed: (_) {}, // Empty function to prevent sending
                  user: types.User(id: userId),
                  showUserAvatars: true,
                  showUserNames: true,
                  dateFormat: DateFormat('MM月dd日'),
                  timeFormat: DateFormat('HH:mm'),
                ),
              ),
              if (isInputEnabled)
                _buildInputField(), // Only show input if enabled
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              enabled: isInputEnabled, // Disable the input field
              decoration: InputDecoration(
                hintText: 'メッセージを入力...',
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: isInputEnabled ? () {} : null, // Disable send button
          ),
        ],
      ),
    );
  }
}
