import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItem {
  final IconData icon;
  final String text;
  final String? imagePath;

  MenuItem({
    required this.icon,
    required this.text,
    this.imagePath,
  });
}

class QandATopPage extends StatefulWidget {
  QandATopPage({Key? key}) : super(key: key);

  @override
  State<QandATopPage> createState() => _QandATopPageState();
}

class _QandATopPageState extends State<QandATopPage> {
  // 検索用TextEditingController
  final TextEditingController _searchController = TextEditingController();

  // ユーザー名を保持する変数
  String userName = '';

  // Firebaseからユーザーデータを読み込むフラグ
  bool isLoading = true;

  // メニュー項目のリスト
  final List<MenuItem> menuItems = [
    MenuItem(icon: Icons.inventory, text: '注文内容について'),
    MenuItem(icon: Icons.account_circle, text: 'アカウントについて'),
    MenuItem(icon: Icons.card_membership, text: 'Amazonプライム会員', imagePath: 'prime'),
    MenuItem(icon: Icons.payment, text: 'お支払い、請求、ギフトカード'),
    MenuItem(icon: Icons.devices, text: 'Kindle、Alexa、その他のAmazonデバイス'),
    MenuItem(icon: Icons.video_library, text: 'Prime Video、Amazon Music、Kindleアプリ、Kids+'),
    MenuItem(icon: Icons.games, text: 'ゲーム&ソフトウェア、Prime Gaming'),
    MenuItem(icon: Icons.warning, text: '不審な荷物および連絡（電話、Eメール、SMS）について'),
    // ここに追加のメニュー項目を追加できます
  ];

  // 検索結果をフィルターするためのリスト
  List<MenuItem> filteredItems = [];

  @override
  void initState() {
    super.initState();
    // 初期状態では全てのアイテムを表示
    filteredItems = List.from(menuItems);

    // 検索テキスト変更時のリスナーを追加
    _searchController.addListener(_filterItems);

    // ユーザー情報の取得
    fetchUserData();
  }

  // ユーザーデータをFirebaseから取得
  Future<void> fetchUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
            .instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data()?['name'] != null) {
          setState(() {
            userName = userDoc.data()?['name'];
            isLoading = false;
          });
        } else {
          setState(() {
            userName = 'ゲスト';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          userName = 'ゲスト';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        userName = 'ゲスト';
        isLoading = false;
      });
    }
  }

  // 検索テキストに基づいてアイテムをフィルタリングする関数
  void _filterItems() {
    setState(() {
      if (_searchController.text.isEmpty) {
        filteredItems = List.from(menuItems);
      } else {
        filteredItems = menuItems
            .where((item) => item.text.toLowerCase().contains(_searchController.text.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    // コントローラーを破棄
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 背景色を白に変更
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F7), // 少し青みがかったグレー
            borderRadius: BorderRadius.circular(20), // より丸みを持たせる
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: '検索または質問する',
              hintStyle: TextStyle(
                color: Color(0xFF6E7491),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Color(0xFF6E7491),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            style: const TextStyle(
              color: Color(0xFF6E7491),
              fontSize: 15,
            ),
            // サブミットされたときの処理
            onSubmitted: (value) {
              // 検索実行ロジック（必要に応じて実装）
              print('検索実行: $value');
            },
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 固定ヘッダー部分 - スクロールしない
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isLoading
                      ? const SizedBox(
                    height: 18,
                    width: 200,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A0C6)),
                    ),
                  )
                      : Text(
                    '$userNameさん、ご希望の操作を選択してください。',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'よくある質問から解決できます。または、問題を解決できる担当者にお繋ぎします。',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // スクロール可能なリスト部分
            Expanded(
              child: Container(
                color: Colors.white, // スクロール部分の背景色も白に
                child: filteredItems.isEmpty
                    ? const Center(
                  child: Text(
                    '該当する項目がありません',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                )
                    : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filteredItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _buildMenuItem(
                      icon: item.icon,
                      text: item.text,
                      color: const Color(0xFF00A0C6),
                      imagePath: item.imagePath,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    String? imagePath,
    required String text,
    required Color color,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: imagePath != null
                ? imagePath == 'prime'
                ? Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.card_membership,
                  color: Colors.white,
                ),
                Positioned(
                  top: 20,
                  child: Container(
                    height: 2,
                    width: 20,
                    color: Colors.red,
                  ),
                ),
              ],
            )
                : Image.asset(
              'assets/images/$imagePath.png',
              width: 24,
              height: 24,
              color: Colors.white,
            )
                : Icon(
              icon,
              color: Colors.white,
            ),
          ),
        ),
        title: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // タップ時の処理
          print('選択されたアイテム: $text');
        },
      ),
    );
  }
}

// To use this widget, import it in main.dart and add it to your routes
// or navigate to it using:
// Navigator.push(
//   context,
//   MaterialPageRoute(builder: (context) => QandATopPage()),
// );