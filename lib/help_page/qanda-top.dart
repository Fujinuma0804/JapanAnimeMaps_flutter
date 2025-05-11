import 'package:flutter/material.dart';

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

class QandATopPage extends StatelessWidget {
  QandATopPage({Key? key}) : super(key: key);

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
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0), // より明確なグレー背景
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)), // 薄いグレーの枠線を追加
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              const Icon(Icons.search, color: Colors.black54),
              const SizedBox(width: 8),
              const Text(
                '検索または質問する',
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            ],
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
                  const Text(
                    '川上さん、ご希望の操作を選択してください',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ここですぐに解決できます。または、問題を解決できる担当者にお繋ぎします。',
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
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: menuItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1),
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
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
        onTap: () {},
      ),
    );
  }
}

// To use this widget, import it in main.dart and add it to your routes
// or navigate to it using:
// Navigator.push(
//   context,
//   MaterialPageRoute(builder: (context) => const QandATopPage()),
// );