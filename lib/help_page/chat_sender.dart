import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';

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
  final String? managementNumber;

  const ChatRoom({
    Key? key,
    required this.userId,
    this.managementNumber,
  }) : super(key: key);

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
  late String _currentManagementNumber;

  @override
  void initState() {
    super.initState();
    _currentManagementNumber =
        widget.managementNumber ?? generateManagementNumber();
    _initializeFirebase();
    _fetchUserData();
    _listenForMessages();
    _checkForCompletedChat();
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

    if (!_hasCompletedChat && widget.managementNumber == null) {
      _addWelcomeMessage();
    }
  }

  void _checkForCompletedChat() async {
    final completedChats = await FirebaseFirestore.instance
        .collection('messages')
        .snapshots()
        .first;

    final completedMessages = completedChats.docs
        .where((doc) =>
            doc.data()['managementNumber'] == _currentManagementNumber &&
            doc.data()['isCompleted'] == true)
        .toList();

    if (completedMessages.isNotEmpty) {
      setState(() {
        _hasCompletedChat = true;
        _isInputDisabled = true;
      });
    }
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

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );

    if (result != null) {
      final bytes = await result.readAsBytes();
      final image = await _uploadImage(bytes, result.name);

      final message = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: randomString(),
        name: result.name,
        size: bytes.length,
        uri: image,
      );

      _addMessage(message);
    }
  }

  Future<String> _uploadImage(Uint8List bytes, String fileName) async {
    final reference = FirebaseStorage.instance
        .ref()
        .child('chat_images')
        .child(_currentManagementNumber)
        .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

    final metadata = SettableMetadata(
      contentType: lookupMimeType(fileName),
    );

    await reference.putData(bytes, metadata);
    return await reference.getDownloadURL();
  }

  void _listenForMessages() {
    FirebaseFirestore.instance
        .collection('messages')
        .snapshots()
        .listen((snapshot) {
      final messages = snapshot.docs
          .where((doc) =>
              doc.data()['managementNumber'] == _currentManagementNumber)
          .map((doc) {
        final data = doc.data();
        final author = data['authorId'] == widget.userId ? _user : _admin;

        if (data['type'] == 'image') {
          return types.ImageMessage(
            author: author,
            createdAt: data['createdAt'] ?? 0,
            id: doc.id,
            name: data['name'],
            size: data['size'],
            uri: data['uri'],
          );
        } else {
          return types.TextMessage(
            author: author,
            createdAt: data['createdAt'] ?? 0,
            id: doc.id,
            text: data['text'],
          );
        }
      }).toList()
        ..sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));

      setState(() {
        _messages.clear();
        _messages.addAll(messages);
        _isInputDisabled = messages.any((message) =>
            message is types.TextMessage &&
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'チャット',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '管理番号: $_currentManagementNumber',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (!_isInputDisabled)
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _handleSendComplete,
              ),
            IconButton(
              icon: const Icon(Icons.update),
              onPressed: _showChatHistory,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator()) // Indicifierから Indicatorに修正
            : Chat(
                theme: DefaultChatTheme(
                  messageBorderRadius: 20,
                  primaryColor: Colors.blue,
                  secondaryColor: Colors.grey[200]!,
                  backgroundColor: Colors.white,
                  inputBackgroundColor: Colors.grey[200]!,
                  sentMessageBodyTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  receivedMessageBodyTextStyle: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
                messages: _messages.toList(),
                onAttachmentPressed: _handleImageSelection,
                onSendPressed: _handleSendPressed,
                showUserAvatars: true,
                showUserNames: true,
                user: _user,
                dateFormat: DateFormat('MM月dd日'),
                timeFormat: DateFormat('HH:mm'),
                customBottomWidget: _isInputDisabled
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton(
                          child: const Text('新しいチャットを開始'),
                          onPressed: _startNewChat,
                        ),
                      )
                    : null,
              ),
      );

  void _handleSendPressed(types.PartialText message) {
    if (_isInputDisabled) return;

    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: randomString(),
      text: message.text,
    );

    _addMessage(textMessage);
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.add(message);
    });

    final messageData = {
      'userId': widget.userId,
      'authorId': message.author.id,
      'createdAt': message.createdAt,
      'managementNumber': _currentManagementNumber,
      'isCompleted': false,
    };

    if (message is types.TextMessage) {
      messageData['type'] = 'text';
      messageData['text'] = message.text;
    } else if (message is types.ImageMessage) {
      messageData['type'] = 'image';
      messageData['uri'] = message.uri;
      messageData['name'] = message.name;
      messageData['size'] = message.size;
    }

    FirebaseFirestore.instance.collection('messages').add(messageData);
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
    _saveChatHistory();

    FirebaseFirestore.instance
        .collection('messages')
        .snapshots()
        .first
        .then((snapshot) {
      final docs = snapshot.docs
          .where((doc) =>
              doc.data()['managementNumber'] == _currentManagementNumber)
          .toList();

      for (var doc in docs) {
        doc.reference.update({'isCompleted': true});
      }
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => ChatHistoryPage(userId: widget.userId)),
    );
  }

  void _saveChatHistory() {
    final chatHistory = _messages.map((message) {
      final Map<String, dynamic> messageData = {
        'authorId': message.author.id,
        'createdAt': message.createdAt,
      };

      if (message is types.TextMessage) {
        messageData['type'] = 'text';
        messageData['text'] = message.text;
      } else if (message is types.ImageMessage) {
        messageData['type'] = 'image';
        messageData['uri'] = message.uri;
        messageData['name'] = message.name;
        messageData['size'] = message.size;
      }

      return messageData;
    }).toList();

    FirebaseFirestore.instance
        .collection('chatSessions')
        .doc(_currentManagementNumber)
        .set({
      'userId': widget.userId,
      'history': chatHistory,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    });

    final lastMessage = _messages.last;
    final lastMessageText =
        lastMessage is types.TextMessage ? lastMessage.text : '画像が送信されました';

    FirebaseFirestore.instance
        .collection('chatHistories')
        .doc(widget.userId)
        .set({
      'history': FieldValue.arrayUnion([
        {
          'managementNumber': _currentManagementNumber,
          'lastMessage': lastMessageText,
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
