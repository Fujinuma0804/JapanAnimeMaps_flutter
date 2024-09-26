import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'news_detail.dart';

class NewsTopPage extends StatefulWidget {
  @override
  _NewsTopPageState createState() => _NewsTopPageState();
}

class _NewsTopPageState extends State<NewsTopPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['トップ', '地域', 'クーポン', 'スマニュー+', 'エンタメ'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.refresh, color: Color(0xFF00008b)),
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 10),
                padding: EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'ニュースを検索',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: Colors.grey),
                  ),
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
            Icon(Icons.settings, color: Color(0xFF00008b)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            height: 48,
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: Color(0xFF00008b),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 14),
              tabs: _tabs
                  .map((String name) => Tab(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            border:
                                Border.all(color: Color(0xFF00008b), width: 2),
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(name),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((String name) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('news').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('エラーが発生しました'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              return ListView(
                children: snapshot.data!.docs.map((DocumentSnapshot document) {
                  Map<String, dynamic> data =
                      document.data() as Map<String, dynamic>;
                  return _buildNewsItem(
                      document.id,
                      data['location'] ?? '',
                      data['title'] ?? '',
                      (data['images'] as List<dynamic>).isNotEmpty
                          ? data['images'][0]
                          : null,
                      data['submissionTime'] ?? Timestamp.now());
                }).toList(),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNewsItem(String newsId, String location, String title,
      String? imageUrl, Timestamp submissionTime) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewsDetailPage(newsId: newsId),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location,
                        style: TextStyle(color: Colors.red),
                      ),
                      SizedBox(height: 5),
                      Text(
                        title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 5),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                DateFormat('yyyy/MM/dd HH:mm').format(submissionTime.toDate()),
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
