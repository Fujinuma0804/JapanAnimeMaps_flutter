import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parts/help_page/qa/qanda-template.dart';
import 'package:parts/help_page/testSendMail.dart';
import 'package:parts/help_page/test_send_mail_http.dart';

class MenuItem {
  final String id;
  final IconData icon;
  final String text;
  final String? imagePath;
  final Color color;

  MenuItem({
    required this.id,
    required this.icon,
    required this.text,
    this.imagePath,
    this.color = const Color(0xFF00A0C6),
  });
}

class QandATopPage extends StatefulWidget {
  const QandATopPage({super.key});

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
    MenuItem(id: 'faq', icon: Icons.help_outline, text: 'よくあるお問い合わせ'),
    MenuItem(id: 'account', icon: Icons.account_circle, text: 'アカウントについて'),
    MenuItem(id: 'premium', icon: Icons.card_membership, text: 'プレミアム会員サービス', color: Colors.amber[700] ?? const Color(0xFFFFB300)),
    MenuItem(id: 'service', icon: Icons.info_outline, text: 'サービスについて'),
    MenuItem(id: 'app', icon: Icons.smartphone, text: 'アプリの使い方'),
    MenuItem(id: 'business', icon: Icons.business, text: 'ビジネス連携について', color: const Color(0xFFFF9800)),
    MenuItem(id: 'technical', icon: Icons.warning_amber, text: '技術的問題とトラブルシューティング'),
    MenuItem(id: 'report', icon: Icons.contact_support_outlined, text: '不審な活動および連絡について', color: const Color(0xFFE91E63)),
  ];

  // Firebaseから読み込むジャンルのキャッシュ
  List<String> availableGenres = [];
  bool genresLoaded = false;

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

    // 利用可能なジャンルをFirebaseから取得しておく
    loadAvailableGenres();
  }

  // Firebaseから利用可能なジャンルを事前に取得
  Future<void> loadAvailableGenres() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('q-a_genres')
          .get();

      final genres = snapshot.docs.map((doc) {
        final data = doc.data();
        return data['name'] as String? ?? doc.id;
      }).toList();

      setState(() {
        availableGenres = genres.whereType<String>().toList();
        genresLoaded = true;
      });

      print('Available genres loaded: $availableGenres');
    } catch (e) {
      print('Error loading genres from Firebase: $e');
      // エラー時は空のリストのままにする
    }
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
            // ElevatedButton(
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: const Color(0xFF00008b),
            //   ),
            //   onPressed: () => showTestEmailDialogHttp(context),
            //   child: Text('テストメール送信 (HTTP版)', style: TextStyle(color: Colors.white)),
            // ),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00008b)),
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
                      item: item,
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
    required MenuItem item,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: item.imagePath != null
                ? item.imagePath == 'prime'
                ? Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
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
              'assets/images/${item.imagePath}.png',
              width: 24,
              height: 24,
              color: Colors.white,
            )
                : Icon(
              item.icon,
              color: Colors.white,
            ),
          ),
        ),
        title: Text(
          item.text,
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // 対応する詳細ページに遷移
          navigateToDetailPage(context, item);
        },
      ),
    );
  }

  // 詳細ページへの遷移処理
  void navigateToDetailPage(BuildContext context, MenuItem item) {
    // メニューIDをジャンル名にマッピング
    String? initialGenre;

    // Firebaseのジャンルデータがロードされているかチェック
    if (genresLoaded && availableGenres.isNotEmpty) {
      switch (item.id) {
        case 'faq':
        // すべてのジャンルを表示（ジャンル未指定）
          initialGenre = null;
          break;
        case 'account':
        // Firebaseのジャンルからアカウント関連ジャンルを検索
          initialGenre = findMatchingGenre(['アカウント', 'アカウントについて']);
          break;
        case 'premium':
        // プレミアムサービス関連ジャンルを検索
          initialGenre = findMatchingGenre(['プレミアム', 'プレミアム会員', 'プレミアム会員サービス']);
          break;
        case 'service':
        // サービス関連ジャンルを検索
          initialGenre = findMatchingGenre(['サービス', 'サービスについて']);
          break;
        case 'app':
        // アプリ関連ジャンルを検索
          initialGenre = findMatchingGenre(['アプリ', 'アプリについて', 'アプリの使い方']);
          break;
        case 'business':
        // ビジネス関連ジャンルを検索
          initialGenre = findMatchingGenre(['ビジネス', 'ビジネス連携', 'ビジネス連携について']);
          break;
        case 'technical':
        // 技術サポート関連ジャンルを検索
          initialGenre = findMatchingGenre(['技術', '技術サポート', 'トラブル', 'トラブルシューティング']);
          break;
        case 'report':
        // お問い合わせ関連ジャンルを検索
          initialGenre = findMatchingGenre(['お問い合わせ', '報告', '連絡', 'レポート']);
          break;
        default:
        // デフォルト処理（例外ケース）
          print('未定義のメニュー項目: ${item.id}');
          initialGenre = null;
          break;
      }
    } else {
      // ジャンルデータがロードされていない場合は従来のマッピングを使用
      switch (item.id) {
        case 'faq':
          initialGenre = null;
          break;
        case 'account':
          initialGenre = 'アカウントについて';
          break;
        case 'premium':
          initialGenre = 'プレミアム会員サービス';
          break;
        case 'service':
          initialGenre = 'サービスについて';
          break;
        case 'app':
          initialGenre = 'アプリについて';
          break;
        case 'business':
          initialGenre = 'ビジネス連携';
          break;
        case 'technical':
          initialGenre = '技術サポート';
          break;
        case 'report':
          initialGenre = 'お問い合わせ';
          break;
        default:
          initialGenre = null;
          break;
      }
    }

    print('Selected genre for ${item.id}: $initialGenre');

    // 選択されたジャンルを初期値として設定したFAQページに遷移
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeToursimFAQPage(initialGenre: initialGenre),
      ),
    );
  }

  // 利用可能なジャンルから最適なマッチを見つける
  String? findMatchingGenre(List<String> possibleMatches) {
    // 完全一致
    for (final match in possibleMatches) {
      if (availableGenres.contains(match)) {
        return match;
      }
    }

    // 部分一致
    for (final genre in availableGenres) {
      for (final match in possibleMatches) {
        if (genre.toLowerCase().contains(match.toLowerCase()) ||
            match.toLowerCase().contains(genre.toLowerCase())) {
          return genre;
        }
      }
    }

    // マッチするものがなければnull
    return null;
  }
}