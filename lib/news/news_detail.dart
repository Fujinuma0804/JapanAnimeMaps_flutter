import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class NewsDetailPage extends StatelessWidget {
  final String newsId;

  NewsDetailPage({required this.newsId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF00008b),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.ios_share,
              color: Color(0xFF00008b),
            ),
            onPressed: () {
              Share.share(
                  'Check out this news article!'); // You can customize this message
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('news')
            .doc(newsId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('ニュースが見つかりません'));
          }

          Map<String, dynamic> data =
              snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    data['title'] ?? '',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _formatDate(data['submissionTime']),
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                if ((data['images'] as List<dynamic>).isNotEmpty)
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: CachedNetworkImage(
                      imageUrl: data['images'][0],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                      placeholder: (context, url) =>
                          CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(data['content'] ?? ''),
                ),
                Divider(),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '関連する記事',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildRelatedNews(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('yyyy/MM/dd HH:mm').format(timestamp.toDate());
  }

  Widget _buildRelatedNews() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('news').limit(5).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return ListTile(
              leading: (data['images'] as List<dynamic>).isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: data['images'][0],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                  : null,
              title: Text(data['title'] ?? ''),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewsDetailPage(newsId: doc.id),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}
