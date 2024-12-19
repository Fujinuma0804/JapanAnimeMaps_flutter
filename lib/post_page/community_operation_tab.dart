import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationDetailScreen extends StatelessWidget {
  final String title;
  final DateTime publishAt;
  final String content;

  const NotificationDetailScreen({
    Key? key,
    required this.title,
    required this.publishAt,
    required this.content,
  }) : super(key: key);

  String _formatDate(DateTime date) {
    return "${date.year}年${date.month}月${date.day}日 ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
    }
  }

  List<TextSpan> _buildTextSpansWithLinks(BuildContext context, String text) {
    List<TextSpan> textSpans = [];

    final urlPattern = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    int lastMatch = 0;
    for (var match in urlPattern.allMatches(text)) {
      if (match.start > lastMatch) {
        textSpans.add(TextSpan(
          text: text.substring(lastMatch, match.start),
          style: TextStyle(
            fontSize: 17,
            height: 1.8,
            color: Colors.grey[800],
            letterSpacing: 0.3,
          ),
        ));
      }

      final url = text.substring(match.start, match.end);
      textSpans.add(TextSpan(
        text: url,
        style: TextStyle(
          fontSize: 17,
          height: 1.8,
          color: Theme.of(context).primaryColor,
          decoration: TextDecoration.underline,
          decorationColor: Theme.of(context).primaryColor.withOpacity(0.5),
          fontWeight: FontWeight.w500,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(url),
      ));

      lastMatch = match.end;
    }

    if (lastMatch < text.length) {
      textSpans.add(TextSpan(
        text: text.substring(lastMatch),
        style: TextStyle(
          fontSize: 17,
          height: 1.8,
          color: Colors.grey[800],
          letterSpacing: 0.3,
        ),
      ));
    }

    return textSpans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF00008b)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade50,
                          Colors.white,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00008b),
                            letterSpacing: 0.5,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.1),
                                    spreadRadius: 0,
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(publishAt),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: RichText(
                  text: TextSpan(
                    children: _buildTextSpansWithLinks(context, content),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String title;
  final DateTime publishAt;
  final String content;

  const NotificationCard({
    Key? key,
    required this.title,
    required this.publishAt,
    required this.content,
  }) : super(key: key);

  String _formatDate(DateTime date) {
    return "${date.year}年${date.month}月${date.day}日 ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  String _truncateContent(String text) {
    final lines = text.split('\n');
    final plainText = lines.join(' ').replaceAll(RegExp(r'https?:\/\/\S+'), '');
    if (plainText.length <= 100) return plainText;
    return '${plainText.substring(0, 97)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotificationDetailScreen(
                title: title,
                publishAt: publishAt,
                content: content,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.blue.shade50.withOpacity(0.5),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.announcement_rounded,
                            color: Color(0xFF00008b),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00008b),
                              height: 1.3,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(publishAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _truncateContent(content),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.grey[800],
                        letterSpacing: 0.2,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '詳細を表示',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Colors.blue[700],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OperationTabContent extends StatelessWidget {
  const OperationTabContent({Key? key}) : super(key: key);

  bool _shouldShowNotification(Map<String, dynamic> notification) {
    final bool isScheduled = notification['isScheduled'] ?? false;
    final Timestamp publishAt = notification['publishAt'] as Timestamp;

    if (!isScheduled) return true;
    return DateTime.now().isAfter(publishAt.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community_operation_notification')
          .orderBy('publishAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.error_outline,
                      size: 48, color: Colors.red[300]),
                ),
                const SizedBox(height: 16),
                Text(
                  'エラーが発生しました\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00008b)),
            ),
          );
        }

        final notifications = snapshot.data!.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .where((notification) => _shouldShowNotification(notification))
            .toList();

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 64,
                    color: Color(0xFF00008b),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '新しいお知らせはありません',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00008b),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '新着のお知らせがあれば\nここに表示されます',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFF00008b),
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationCard(
                title: notification['title'] ?? '無題のお知らせ',
                publishAt: (notification['publishAt'] as Timestamp).toDate(),
                content: notification['content'] ?? '',
              );
            },
          ),
        );
      },
    );
  }
}
