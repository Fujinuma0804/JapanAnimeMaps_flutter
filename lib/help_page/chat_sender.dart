import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:intl/intl.dart';

import 'chat_history.dart';

String randomString() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(255));
  return base64UrlEncode(values);
}

String generateManagementNumber() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return List.generate(15, (index) => chars[random.nextInt(chars.length)])
      .join();
}

class ChatRoom extends StatefulWidget {
  final String userId;
  const ChatRoom({Key? key, required this.userId}) : super(key: key);

  @override
  ChatRoomState createState() => ChatRoomState();
}

class ChatRoomState extends State<ChatRoom> {
  final List<types.Message> _messages = [];
  late types.User _user;
  final _admin = const types.User(
    id: 'admin',
    firstName: "運営",
    lastName: "管理者",
  );

  bool _isInputDisabled = false;
  bool _isLoading = true;
  bool _hasCompletedChat = false;
  String _currentManagementNumber = '';

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _fetchUserData();
    _listenForMessages();
    _checkForCompletedChat();
    _currentManagementNumber = generateManagementNumber();
  }

  void _initializeFirebase() async {
    await Firebase.initializeApp();
  }

  void _fetchUserData() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (!userDoc.exists) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({
        'name': 'ユーザー名',
        'avatarUrl': 'https://example.com/avatar.png',
      });
      userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
    }

    Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

    setState(() {
      _user = types.User(
        id: widget.userId,
        firstName: userData['name'],
        imageUrl: userData['avatarUrl'],
      );
      _isLoading = false;
    });

    if (!_hasCompletedChat) {
      _addWelcomeMessage();
    }
  }

  void _checkForCompletedChat() async {
    final completedChats = await FirebaseFirestore.instance
        .collection('messages')
        .where('userId', isEqualTo: widget.userId)
        .where('isCompleted', isEqualTo: true)
        .get();

    if (completedChats.docs.isNotEmpty) {
      setState(() {
        _hasCompletedChat = true;
      });
      _showRestartDialog();
    }
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('チャットを再開しますか？'),
          content: Text('以前の会話が終了しています。新しい会話を始めますか？'),
          actions: <Widget>[
            TextButton(
              child: Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('再開する'),
              onPressed: () {
                Navigator.of(context).pop();
                _startNewChat();
              },
            ),
          ],
        );
      },
    );
  }

  void _addWelcomeMessage() {
    _addMessage(types.TextMessage(
      author: _admin,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: randomString(),
      text:
          "チャットお問い合わせへようこそ。\nお問い合わせ内容を具体的に送信してください。\n送信が終了しましたら、送信完了をタップしてください。\n通常、1日以内に回答いたします。\n※内容によってはご回答にお時間をいただくことがあります。",
    ));
  }

  void _listenForMessages() {
    FirebaseFirestore.instance
        .collection('messages')
        .where('userId', isEqualTo: widget.userId)
        .where('managementNumber', isEqualTo: _currentManagementNumber)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final messages = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return types.TextMessage(
          author: data['authorId'] == widget.userId ? _user : _admin,
          createdAt: data['createdAt'],
          id: doc.id,
          text: data['text'],
        );
      }).toList();

      setState(() {
        _messages.clear();
        _messages.addAll(messages);
        _isInputDisabled = messages.any((message) =>
            message.text == "このチャットは終了しました。" &&
            message.author.id == widget.userId);
        _hasCompletedChat = _isInputDisabled;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'チャット',
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
          actions: [
            if (!_isInputDisabled)
              IconButton(
                icon: Icon(Icons.check),
                onPressed: _handleSendComplete,
              ),
            IconButton(
              icon: Icon(Icons.update),
              onPressed: _showChatHistory,
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Chat(
                user: _user,
                messages: _messages,
                onSendPressed: _handleSendPressed,
                showUserAvatars: true,
                showUserNames: true,
                dateFormat: DateFormat('MM月dd日'),
                timeFormat: DateFormat('HH:mm'),
                customBottomWidget: _isInputDisabled
                    ? Container(
                        padding: EdgeInsets.all(16),
                        child: ElevatedButton(
                          child: Text('新しいチャットを開始'),
                          onPressed: _startNewChat,
                        ),
                      )
                    : null,
              ),
      );

  void _handleSendPressed(types.PartialText message) {
    if (_isInputDisabled) {
      return;
    }

    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: randomString(),
      text: message.text,
    );

    _addMessage(textMessage);
  }

  void _addMessage(types.TextMessage message) {
    setState(() {
      _messages.insert(0, message);
    });

    FirebaseFirestore.instance.collection('messages').add({
      'userId': widget.userId,
      'authorId': message.author.id,
      'createdAt': message.createdAt,
      'text': message.text,
      'isCompleted': false,
      'managementNumber': _currentManagementNumber,
    });
  }

  void _handleSendComplete() {
    setState(() {
      _isInputDisabled = true;
    });

    final completeMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: randomString(),
      text: "このチャットは終了しました。",
    );

    _addMessage(completeMessage);

    // チャット履歴をFirestoreに保存
    _saveChatHistory();

    FirebaseFirestore.instance
        .collection('messages')
        .where('userId', isEqualTo: widget.userId)
        .where('managementNumber', isEqualTo: _currentManagementNumber)
        .get()
        .then((snapshot) {
      for (DocumentSnapshot doc in snapshot.docs) {
        doc.reference.update({'isCompleted': true});
      }
    });

    // チャット履歴ページに遷移
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => ChatHistoryPage(userId: widget.userId)),
    );
  }

  void _saveChatHistory() {
    final chatHistory = _messages
        .map((message) => {
              'authorId': message.author.id,
              'text': (message as types.TextMessage).text,
              'createdAt': message.createdAt,
            })
        .toList();

    // 新しいコレクションに管理番号とトーク履歴を格納
    FirebaseFirestore.instance
        .collection('chatSessions')
        .doc(_currentManagementNumber)
        .set({
      'userId': widget.userId,
      'history': chatHistory,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    });

    // ユーザーのチャット履歴も更新
    FirebaseFirestore.instance
        .collection('chatHistories')
        .doc(widget.userId)
        .set({
      'history': FieldValue.arrayUnion([
        {
          'managementNumber': _currentManagementNumber,
          'lastMessage': chatHistory.last['text'],
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        }
      ]),
    }, SetOptions(merge: true));
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _isInputDisabled = false;
      _currentManagementNumber = generateManagementNumber();
    });
    _addWelcomeMessage();
  }

  void _showChatHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ChatHistoryPage(userId: widget.userId)),
    );
  }
}
