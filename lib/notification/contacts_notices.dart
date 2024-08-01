import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_svg/flutter_html_svg.dart';
import 'package:intl/intl.dart';
import 'package:translator/translator.dart';

class ContactUsTab extends StatefulWidget {
  const ContactUsTab({Key? key}) : super(key: key);

  @override
  _ContactUsTabState createState() => _ContactUsTabState();
}

class _ContactUsTabState extends State<ContactUsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final translator = GoogleTranslator();
  Map<String, String?> userLanguages = {};

  final Map<String, IconData> priorityIcons = {
    'Critical': Icons.warning,
    'Important': Icons.star,
    'Normal': Icons.info,
    'Attention': Icons.help,
  };

  final Map<String, String> priorityLabels = {
    'Critical': '最重要',
    'Important': '重要',
    'Normal': '通常',
    'Attention': '注意',
  };

  @override
  void initState() {
    super.initState();
    _getUserLanguages();
  }

  Future<void> _getUserLanguages() async {
    var usersSnapshot = await _firestore.collection('users').get();
    Map<String, String?> languages = {};
    for (var doc in usersSnapshot.docs) {
      languages[doc.id] = doc.data()['language'] as String?;
    }
    setState(() {
      userLanguages = languages;
    });
  }

  Future<String> translateToEnglish(String text, String? language) async {
    if (language == 'English') {
      final translation = await translator.translate(text, to: 'en');
      return translation.text;
    }
    return text;
  }

  String formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('yyyy年MM月dd日 HH時mm分').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('usernotification')
          .where('priority', whereIn: ['Attention']).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('通知はありません'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var notice = snapshot.data!.docs[index];
            return FutureBuilder<String>(
              future: translateToEnglish(
                notice['title'],
                userLanguages[notice['user']],
              ),
              builder: (context, translatedSnapshot) {
                if (translatedSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return ListTile(title: Text('Please wait...'));
                }
                return ListTile(
                  leading: Icon(
                    priorityIcons[notice['priority']] ?? Icons.star,
                    color: priorityIcons[notice['priority']] == Icons.warning
                        ? Colors.red
                        : null,
                  ),
                  title: Text(translatedSnapshot.data ?? notice['title']),
                  subtitle: Text(priorityLabels[notice['priority']] ??
                      '優先度: ${notice['priority']}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoticeDetailScreen(
                            notice: notice, priorityLabels: priorityLabels),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class NoticeDetailScreen extends StatelessWidget {
  final QueryDocumentSnapshot notice;
  final Map<String, String> priorityLabels;

  const NoticeDetailScreen(
      {Key? key, required this.notice, required this.priorityLabels})
      : super(key: key);

  String formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('yyyy年MM月dd日 HH時mm分').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          notice['title'],
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                '${notice['title']}',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20.0,
                ),
              ),
            ),
            SizedBox(height: 8),
            notice['body'] != null
                ? Expanded(
                    child: SingleChildScrollView(
                      child: Html(
                        data: notice['body'],
                        style: {
                          "img": Style(
                            display: Display.block,
                          ),
                        },
                        extensions: [
                          SvgHtmlExtension(),
                          ImageExtension(
                            builder: (context) {
                              final attributes = context.attributes;
                              final url = attributes['src'];
                              return Container(
                                margin: EdgeInsets.symmetric(vertical: 10),
                                child: url != null
                                    ? Image.network(
                                        url,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          print("Image URL: $url");
                                          return Text('Failed to load image');
                                        },
                                      )
                                    : Text('No image URL provided'),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : Text('内容: ${notice['body']}'),
            SizedBox(height: 8),
            Text('日付: ${formatDate(notice['date'])}'),
            SizedBox(height: 8),
            Text('${priorityLabels[notice['priority']] ?? notice['priority']}'),
            SizedBox(height: 8),
            Text('発信者：${notice['user']}'),
          ],
        ),
      ),
    );
  }
}
