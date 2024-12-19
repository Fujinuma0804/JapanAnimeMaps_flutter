import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/post_page/community_list_detail.dart';
import 'package:parts/post_page/post_first/community_chat_settings.dart';
import 'package:parts/src/bottomnavigationbar.dart';

// Community model
class Community {
  final String id;
  final String displayName;
  final String description;
  final String backgroundImageUrl;
  final int memberCount;
  final String hashtag;
  final String name;

  Community({
    required this.id,
    required this.displayName,
    required this.description,
    required this.backgroundImageUrl,
    required this.memberCount,
    required this.hashtag,
    required this.name,
  });

  factory Community.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Community(
      id: doc.id,
      displayName: data['displayName'] ?? '',
      description: data['description'] ?? '',
      backgroundImageUrl: data['backgroundImageUrl'] ?? '',
      memberCount: data['memberCount'] ?? 0,
      hashtag: data['hashtag'] ?? '',
      name: data['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'description': description,
      'backgroundImageUrl': backgroundImageUrl,
      'memberCount': memberCount,
      'hashtag': hashtag,
      'name': name,
    };
  }
}

// Event model
class Event {
  final String title;
  final DateTime date;
  final String communityId;
  final String createdBy;

  Event({
    required this.title,
    required this.date,
    required this.communityId,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': date,
      'communityId': communityId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// Message model
class Message {
  final String sender;
  final String content;
  final DateTime timestamp;
  final bool isMe;
  final String userIcon;
  final String userId;
  final bool isEvent;

  Message({
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.isMe,
    required this.userIcon,
    required this.userId,
    this.isEvent = false,
  });

  factory Message.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      sender: data['userName'] ?? '',
      content: data['text'] ?? '',
      timestamp: (data['createdAt'] as Timestamp).toDate(),
      isMe: data['userId'] == currentUserId,
      userIcon: data['iconUrl'] ?? '',
      userId: data['userId'] ?? '',
      isEvent: data['isEvent'] ?? false,
    );
  }
}

class GroupChatScreen extends StatefulWidget {
  final String roomName;
  final String communityId;
  final int participantCount;

  const GroupChatScreen({
    Key? key,
    required this.roomName,
    required this.communityId,
    required this.participantCount,
  }) : super(key: key);

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  DateTime? _selectedDate;

  Stream<QuerySnapshot> _getMessages() {
    return _firestore
        .collection('community_list')
        .doc(widget.communityId)
        .collection('chat')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<Community?> _getCommunityStream() {
    return _firestore
        .collection('community_list')
        .doc(widget.communityId)
        .snapshots()
        .map((doc) => doc.exists ? Community.fromFirestore(doc) : null);
  }

  void _handleMessageInput(String value) {
    if (value.startsWith('/') && value.length == 9) {
      try {
        final year = int.parse(value.substring(1, 5));
        final month = int.parse(value.substring(5, 7));
        final day = int.parse(value.substring(7, 9));
        final date = DateTime(year, month, day);

        setState(() {
          _selectedDate = date;
          _messageController.clear();
        });
      } catch (e) {
        // 日付形式が不正な場合は何もしない
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      if (_selectedDate != null) {
        // 予定として保存
        final event = Event(
          title: _messageController.text,
          date: _selectedDate!,
          communityId: widget.communityId,
          createdBy: currentUser?.uid ?? '',
        );

        await _firestore
            .collection('community_list')
            .doc(widget.communityId)
            .collection('events')
            .add(event.toMap());

        // チャットにも予定を投稿
        await _firestore
            .collection('community_list')
            .doc(widget.communityId)
            .collection('chat')
            .add({
          'text':
              '📅 ${_messageController.text}\n日時: ${_selectedDate!.year}/${_selectedDate!.month}/${_selectedDate!.day}',
          'createdAt': FieldValue.serverTimestamp(),
          'userId': currentUser?.uid,
          'userName': currentUser?.displayName ?? 'Anonymous',
          'userIcon': currentUser?.photoURL ?? '',
          'isEvent': true,
        });

        setState(() {
          _selectedDate = null;
        });
      } else {
        // 通常のメッセージとして保存
        await _firestore
            .collection('community_list')
            .doc(widget.communityId)
            .collection('chat')
            .add({
          'text': _messageController.text,
          'createdAt': FieldValue.serverTimestamp(),
          'userId': currentUser?.uid,
          'userName': currentUser?.displayName ?? 'Anonymous',
          'userIcon': currentUser?.photoURL ?? '',
          'isEvent': false,
        });
      }

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メッセージの送信に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.roomName} (${widget.participantCount})',
          style: const TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => MainScreen(
                          initalIndex: 3,
                        )));
          },
          icon: Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF00008b),
          ),
        ),
        actions: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StreamBuilder<Community?>(
                        stream: _getCommunityStream(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('エラーが発生しました'));
                          }
                          if (!snapshot.hasData || snapshot.data == null) {
                            return Center(child: CircularProgressIndicator());
                          }
                          return CommunityDetailScreen(
                            community: snapshot.data!.toMap(),
                          );
                        },
                      ),
                    ),
                  );
                },
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF00008b),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MenuScreen(
                        communityId: widget.communityId,
                      ),
                    ),
                  );
                },
                icon: Icon(
                  Icons.menu,
                  color: Color(0xFF00008b),
                ),
              ),
            ],
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getMessages(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs.map((doc) {
                  return Message.fromFirestore(doc, currentUser?.uid ?? '');
                }).toList();

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isMe) ...[
            CircleAvatar(
              backgroundImage: message.userIcon.isNotEmpty
                  ? NetworkImage(message.userIcon)
                  : null,
              child: message.userIcon.isEmpty ? Text(message.sender[0]) : null,
              radius: 16,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!message.isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      message.sender,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: message.isMe
                        ? const Color(0xFF00008b)
                        : (message.isEvent
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: message.isMe
                          ? Colors.white
                          : (message.isEvent ? Colors.blue : Colors.black),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.isMe) const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Column(
      children: [
        if (_selectedDate != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '予定日: ${_selectedDate!.year}/${_selectedDate!.month}/${_selectedDate!.day}',
                  style: TextStyle(color: Colors.blue),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: Colors.blue),
                  onPressed: () {
                    setState(() {
                      _selectedDate = null;
                    });
                  },
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, -2),
                blurRadius: 4,
                color: Colors.black.withOpacity(0.1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: _selectedDate != null ? '予定を入力' : 'メッセージを入力',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onChanged: _handleMessageInput,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF00008b),
                child: IconButton(
                  icon: const Icon(
                    Icons.send,
                    color: Colors.white,
                  ),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

// EventsScreen implementation
class EventsScreen extends StatelessWidget {
  final String communityId;

  const EventsScreen({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('イベント'),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF00008b),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('community_list')
            .doc(communityId)
            .collection('events')
            .orderBy('date')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました'));
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data!.docs;

          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index].data() as Map<String, dynamic>;
              final date = (event['date'] as Timestamp).toDate();

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(Icons.event, color: Colors.blue),
                  title: Text(event['title']),
                  subtitle: Text(
                    '${date.year}/${date.month}/${date.day}',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
