import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MyStorePassportScreen extends StatefulWidget {
  const MyStorePassportScreen({Key? key}) : super(key: key);

  @override
  _MyStorePassportScreenState createState() => _MyStorePassportScreenState();
}

class _MyStorePassportScreenState extends State<MyStorePassportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> stamps = [];
  List<Map<String, dynamic>> rankings = [
    {
      'rank': 1,
      'name': '山田太郎',
      'points': 1250,
      'iconUrl': 'https://example.com/avatar1.jpg'
    },
    {
      'rank': 2,
      'name': '佐藤花子',
      'points': 980,
      'iconUrl': 'https://example.com/avatar2.jpg'
    },
    {
      'rank': 3,
      'name': '鈴木一郎',
      'points': 850,
      'iconUrl': 'https://example.com/avatar3.jpg'
    },
    // 以下略
  ];

  // 残り日数を計算するメソッドを追加
  String _getRemainingDays() {
    DateTime now = DateTime.now();
    DateTime nextMonday = now.add(
      Duration(
        days: (DateTime.monday - now.weekday + 7) % 7,
      ),
    );

    // 現在が月曜日で、まだ更新時刻前の場合は、その日を次の更新日とする
    if (now.weekday == DateTime.monday) {
      final updateTime =
          DateTime(now.year, now.month, now.day, 5, 0); // 午前5時を更新時刻とする
      if (now.isBefore(updateTime)) {
        nextMonday = now;
      }
    }

    // 次の更新日の午前5時に設定
    nextMonday = DateTime(
      nextMonday.year,
      nextMonday.month,
      nextMonday.day,
      5, // 午前5時
      0,
    );

    final remaining = nextMonday.difference(now);
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;

    if (days > 0) {
      return '残り${days}日';
    } else if (hours > 0) {
      return '残り${hours}時間';
    } else {
      final minutes = remaining.inMinutes % 60;
      return '残り${minutes}分';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchStamps();
  }

  Future<void> _fetchStamps() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('stamps').get();
    setState(() {
      stamps = snapshot.docs.map((doc) => doc.data()).toList();
    });
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
        centerTitle: false,
        title: Text(
          'マイパスポート',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF00008b),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.help_outline,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(child: _buildTabBarView()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Color(0xFF00008b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '全国の聖地巡礼でスタンプが貯まる！\nポイントも合わせて貯めてスタンプをコンプリートしよう！\nランキングは月曜日に更新されます。',
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.flight_takeoff_outlined, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'スタンプ数 7',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: [
        Tab(text: 'スタンプ'),
        Tab(text: 'ランキング'),
        Tab(text: 'イベント'),
      ],
      labelColor: Color(0xFF00008b),
      unselectedLabelColor: Colors.black54,
      indicatorColor: Color(0xFF00008b),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildStampGrid(),
        _buildMedalGrid(),
        _buildHowToEnjoy(),
      ],
    );
  }

  Widget _buildStampGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        if (index < stamps.length) {
          return _buildStamp(stamps[index]);
        }
        return _buildEmptyStamp();
      },
    );
  }

  Widget _buildStamp(Map<String, dynamic> stamp) {
    return GestureDetector(
      onTap: () => _showStampDetail(stamp),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: stamp['imageUrl'] != null
                  ? Image.network(
                      stamp['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Center(child: Text('Error loading image')),
                    )
                  : Center(child: Text('Coming Soon')),
            ),
          ),
          SizedBox(height: 4),
          Text(
            stamp['label'] ?? '',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStamp() {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(child: Text('Coming Soon')),
          ),
        ),
        SizedBox(height: 4),
        Text(
          '',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  void _showStampDetail(Map<String, dynamic> stamp) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                stamp['imageUrl'] != null
                    ? Image.network(
                        stamp['imageUrl'],
                        fit: BoxFit.contain,
                        height: 200,
                        errorBuilder: (context, error, stackTrace) =>
                            Center(child: Text('Error loading image')),
                      )
                    : Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: Center(child: Text('Coming Soon')),
                      ),
                SizedBox(height: 16),
                Text(
                  stamp['title'] ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  stamp['label'] ?? '',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00008b),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '閉じる',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedalGrid() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '今週のランキング',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getRemainingDays(),
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rankings.length,
            itemBuilder: (context, index) {
              final ranking = rankings[index];
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // ランキング表示
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getRankColor(ranking['rank']),
                      ),
                      child: Center(
                        child: Text(
                          '${ranking['rank']}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // ユーザーアイコン
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          ranking['iconUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // ユーザー名
                    Expanded(
                      child: Text(
                        ranking['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // ポイント表示
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${ranking['points']} pt',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00008b),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // 金
      case 2:
        return Colors.grey[400]!; // 銀
      case 3:
        return Colors.brown[300]!; // 銅
      default:
        return Colors.grey[600]!; // その他
    }
  }

  Widget _buildHowToEnjoy() {
    return Center(child: Text('現在はイベントは行われていません。'));
  }
}
