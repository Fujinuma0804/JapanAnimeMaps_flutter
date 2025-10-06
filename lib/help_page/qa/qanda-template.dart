import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'qa_form.dart'; // 追加：お問い合わせフォームのインポート

class FAQModel {
  final String id;
  final String question;
  final String answer;
  final String genre;
  final String title;
  final Timestamp createdAt;
  final Timestamp lastUpdated;
  final String questionId;

  FAQModel({
    required this.id,
    required this.question,
    required this.answer,
    required this.genre,
    required this.title,
    required this.createdAt,
    required this.lastUpdated,
    required this.questionId,
  });

  factory FAQModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FAQModel(
      id: doc.id,
      question: data['question'] ?? '',
      answer: data['answer'] ?? '',
      genre: data['genre'] ?? '',
      title: data['title'] ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      lastUpdated: data['lastUpdated'] as Timestamp? ?? Timestamp.now(),
      questionId: data['questionId'] ?? '',
    );
  }
}

// 評価結果を管理するサービスクラス
class FAQRatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ユーザーが既に評価済みかどうかをチェック
  static Future<bool> hasUserRated(String questionId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('faq_ratings')
          .doc('${questionId}_${user.uid}')
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking user rating: $e');
      return false;
    }
  }

  // 評価を保存
  static Future<bool> saveRating(String questionId, bool isHelpful) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('User not authenticated');
      return false;
    }

    try {
      final batch = _firestore.batch();

      // ユーザーの評価記録を保存
      final ratingRef = _firestore
          .collection('faq_ratings')
          .doc('${questionId}_${user.uid}');

      batch.set(ratingRef, {
        'questionId': questionId,
        'userId': user.uid,
        'isHelpful': isHelpful,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // FAQ文書の評価カウントを更新
      final faqRef = _firestore.collection('q-a_list').doc(questionId);

      if (isHelpful) {
        batch.update(faqRef, {
          'helpfulCount': FieldValue.increment(1),
        });
      } else {
        batch.update(faqRef, {
          'notHelpfulCount': FieldValue.increment(1),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error saving rating: $e');
      return false;
    }
  }

  // 匿名ログイン（ユーザーがログインしていない場合）
  static Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      print('Error signing in anonymously: $e');
      return null;
    }
  }

  // 現在のユーザーを取得（必要に応じて匿名ログイン）
  static Future<User?> getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user == null) {
      user = await signInAnonymously();
    }
    return user;
  }
}

class AnimeToursimFAQPage extends StatefulWidget {
  final String? initialGenre; // 初期表示するジャンル（nullの場合は全て表示）

  const AnimeToursimFAQPage({super.key, this.initialGenre});

  @override
  State<AnimeToursimFAQPage> createState() => _AnimeToursimFAQPageState();
}

class _AnimeToursimFAQPageState extends State<AnimeToursimFAQPage> {
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  List<FAQModel> faqItems = [];
  List<FAQModel> filteredItems = [];
  String? selectedGenre;
  List<String?> genres = [null]; // すべて表示用をデフォルトで含める

  // サンプルFAQデータ（Firestoreが使用できない場合のフォールバック）
  final List<Map<String, dynamic>> sampleFAQData = [
    {
      'id': '1',
      'question': 'JapanAnimeMapsとは何ですか？',
      'answer': 'JapanAnimeMapsは、日本全国のアニメ聖地巡礼スポットを集めた位置情報アプリです。アニメの舞台となった場所や、関連イベント情報などを簡単に検索できます。ユーザー同士でスポット情報を共有することもでき、アニメファンのための新しい旅行体験を提供しています。',
      'genre': 'サービスについて',
      'title': 'アプリの基本情報',
      'createdAt': Timestamp.now(),
      'lastUpdated': Timestamp.now(),
      'questionId': '20250511-1TYSwyszMkSwq',
    },
    {
      'id': '2',
      'question': 'どのようなサービスを提供していますか？',
      'answer': '当社は主に3つのサービスを提供しています。\n1. JapanAnimeMapsの開発・運営：アニメ聖地巡礼のためのスマートフォンアプリ\n2. 地域活性化事業：アニメツーリズムを活用した地域振興企画\n3. 受託開発事業：アニメ関連のアプリやウェブサイトの開発',
      'genre': 'サービスについて',
      'title': 'サービス内容',
      'createdAt': Timestamp.now(),
      'lastUpdated': Timestamp.now(),
      'questionId': '20250511-2TYSwyszMkSwq',
    },
    {
      'id': '3',
      'question': 'アカウントの作成方法を教えてください',
      'answer': 'アプリまたはウェブサイトから「アカウント作成」ボタンをタップし、必要情報を入力することでアカウントを作成できます。メールアドレスの他、Google、Apple、Twitterのアカウントを利用したサインアップも可能です。',
      'genre': 'アカウントについて',
      'title': 'アカウント作成方法',
      'createdAt': Timestamp.now(),
      'lastUpdated': Timestamp.now(),
      'questionId': '20250511-3TYSwyszMkSwq',
    },
    {
      'id': '4',
      'question': 'アプリはどこからダウンロードできますか？',
      'answer': 'iOSをご利用の方はApp Store、Androidをご利用の方はGoogle Playからダウンロードいただけます。',
      'genre': 'アプリについて',
      'title': 'アプリダウンロード',
      'createdAt': Timestamp.now(),
      'lastUpdated': Timestamp.now(),
      'questionId': '20250511-4TYSwyszMkSwq',
    },
    {
      'id': '5',
      'question': '自治体としてアニメツーリズムを活用したいのですが、どのような連携が可能ですか？',
      'answer': '当社では自治体様との連携として、地域の観光資源とアニメを組み合わせたプロモーション企画、オリジナルスタンプラリーの実施、アプリ内での地域特集ページの作成など、様々な取り組みを行っています。地域の特性に合わせたカスタムプランをご提案いたしますので、お気軽にお問い合わせください。',
      'genre': 'ビジネス連携',
      'title': '自治体との連携',
      'createdAt': Timestamp.now(),
      'lastUpdated': Timestamp.now(),
      'questionId': '20250511-5TYSwyszMkSwq',
    },
    {
      'id': '6',
      'question': '不適切な投稿を見つけた場合どうすればいいですか？',
      'answer': '不適切な投稿を発見された場合は、該当投稿の右上にある「・・・」メニューから「報告する」を選択してください。報告内容を確認の上、当社ガイドラインに違反していると判断した場合は、速やかに対応いたします。',
      'genre': 'お問い合わせ',
      'title': '不適切投稿の報告',
      'createdAt': Timestamp.now(),
      'lastUpdated': Timestamp.now(),
      'questionId': '20250511-6TYSwyszMkSwq',
    },
  ];

  // サンプルジャンルデータ（Firestoreからの取得に失敗した場合のフォールバック）
  final List<String> sampleGenres = [
    'サービスについて',
    'アカウントについて',
    'アプリについて',
    'ビジネス連携',
    'お問い合わせ',
  ];

  @override
  void initState() {
    super.initState();
    selectedGenre = widget.initialGenre;
    _searchController.addListener(_filterItems);

    // デバッグ情報
    print('Initial genre set in initState: $selectedGenre');

    _loadGenres(); // ジャンルを先に読み込む
  }

  // Firebase からジャンルを読み込む
  Future<void> _loadGenres() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('q-a_genres')
          .get();

      final loadedGenres = snapshot.docs.map((doc) {
        final data = doc.data();
        // ドキュメントのフィールド名に応じて調整（name や value など想定）
        return data['name'] as String? ?? doc.id;
      }).toList();

      setState(() {
        // 初期ジャンルがあれば、そのジャンルを先頭に移動して並べ替える
        if (widget.initialGenre != null && loadedGenres.contains(widget.initialGenre)) {
          // 選択されているジャンルを一旦除外して先頭に追加
          final sortedGenres = [widget.initialGenre!, ...loadedGenres.where((g) => g != widget.initialGenre)];
          // "すべて" を先頭に追加
          genres = [null, ...sortedGenres];
          selectedGenre = widget.initialGenre;
        } else {
          // 通常の並び替え
          genres = [null, ...loadedGenres];

          // ジャンルが読み込まれた後に、初期ジャンル選択を再設定
          // これによって、初期ジャンルがジャンルリストに存在するかを確認
          if (widget.initialGenre != null) {
            // 完全一致するジャンルがあるか確認
            if (loadedGenres.contains(widget.initialGenre)) {
              selectedGenre = widget.initialGenre;

              // 選択されているジャンルを一番左に移動（"すべて"の次）
              genres = [null, widget.initialGenre!, ...loadedGenres.where((g) => g != widget.initialGenre)];
            }
            // 部分一致するジャンルがあるか確認（念のため）
            else {
              final similarGenre = loadedGenres.firstWhere(
                    (genre) => genre.toLowerCase().contains(widget.initialGenre!.toLowerCase()) ||
                    widget.initialGenre!.toLowerCase().contains(genre.toLowerCase()),
                orElse: () => null as String,
              );

              if (similarGenre != null) {
                selectedGenre = similarGenre;
                print('Selected similar genre: $similarGenre instead of ${widget.initialGenre}');

                // 部分一致したジャンルを一番左に移動（"すべて"の次）
                genres = [null, similarGenre, ...loadedGenres.where((g) => g != similarGenre)];
              }
            }
          }
        }
      });

      // ジャンル読み込み後にFAQデータを読み込む
      _loadFAQData();
    } catch (e) {
      print('Error loading genres from Firestore: $e');

      // エラー時はサンプルジャンルを使用
      setState(() {
        genres = [null, ...sampleGenres];

        // サンプルジャンルの場合も初期ジャンル選択を確認
        if (widget.initialGenre != null && sampleGenres.contains(widget.initialGenre)) {
          selectedGenre = widget.initialGenre;

          // 選択されているジャンルを一番左に移動（"すべて"の次）
          genres = [null, widget.initialGenre!, ...sampleGenres.where((g) => g != widget.initialGenre)];
        }
      });

      // ジャンル読み込み後にFAQデータを読み込む
      _loadFAQData();
    }

    // デバッグログ
    print('Selected genre after loading: $selectedGenre');
    print('Available genres: $genres');
  }

  // FAQ データを読み込む（Firestoreからの取得を試み、失敗したらサンプルデータを使用）
  void _loadFAQData() {
    setState(() {
      isLoading = true;
    });

    // まずFirestoreからの取得を試みる
    _loadFromFirestore().then((_) {
      setState(() {
        isLoading = false;
        _filterItems(); // 初期フィルタリング
      });
    }).catchError((error) {
      print('Firestore error, using sample data: $error');

      // Firestoreからの取得に失敗した場合はサンプルデータを使用
      _loadFromSampleData();

      setState(() {
        isLoading = false;
        _filterItems(); // 初期フィルタリング
      });
    });
  }

  // Firestoreからデータを取得する
  Future<void> _loadFromFirestore() async {
    try {
      // シンプルにすべてのデータを取得（クエリなし）
      final snapshot = await FirebaseFirestore.instance
          .collection('q-a_list')
          .get();

      faqItems = snapshot.docs.map((doc) => FAQModel.fromFirestore(doc)).toList();

      // 必要に応じてローカルでソート（createdAtの降順）
      faqItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('Error loading from Firestore: $e');
      throw e; // エラーを上位に伝播させる
    }
  }

  // サンプルデータからFAQアイテムを生成
  void _loadFromSampleData() {
    faqItems = sampleFAQData.map((data) => FAQModel(
      id: data['id'],
      question: data['question'],
      answer: data['answer'],
      genre: data['genre'],
      title: data['title'],
      createdAt: data['createdAt'],
      lastUpdated: data['lastUpdated'],
      questionId: data['questionId'],
    )).toList();
  }

  // 検索テキストとジャンルに基づいてアイテムをフィルタリングする関数
  void _filterItems() {
    setState(() {
      filteredItems = faqItems.where((item) {
        // ジャンルフィルター
        bool matchesGenre = selectedGenre == null || item.genre == selectedGenre;

        // テキスト検索フィルター
        bool matchesSearch = _searchController.text.isEmpty ||
            item.question.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            item.answer.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            item.title.toLowerCase().contains(_searchController.text.toLowerCase());

        return matchesGenre && matchesSearch;
      }).toList();
    });
  }

  // テキストをクリップボードにコピー
  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('コピーしました'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // お問い合わせフォームへの遷移（修正済み）
  void _navigateToContactForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QAFormPage(
          initialGenre: selectedGenre, // 現在選択されているジャンルを渡す
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 選択されているジャンルに応じたタイトルを設定
    String appBarTitle = 'よくあるお問い合わせ';
    if (selectedGenre != null) {
      appBarTitle = 'よくあるお問い合わせ';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appBarTitle,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (selectedGenre != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getGenreColor(selectedGenre!).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    selectedGenre!,
                    style: TextStyle(
                      color: _getGenreColor(selectedGenre!),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(24),
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
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // ジャンル選択タブ - Firebase から読み込んだジャンルを表示
          SizedBox(
            height: 48,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: genres.length,
              itemBuilder: (context, index) {
                final genre = genres[index];
                final isSelected = selectedGenre == genre;
                final label = genre ?? 'すべて';

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        selectedGenre = genre;
                        _filterItems();
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF00A0C6) : const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // FAQ一覧
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                ? const Center(
              child: Text(
                '該当する質問がありません',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return _buildFAQItem(item);
              },
            ),
          ),

          // お問い合わせリンク（修正済み）
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'お探しの情報が見つかりませんか？',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '上記で解決しない場合は、お気軽にお問い合わせください。通常3営業日以内にご返答いたします。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _navigateToContactForm, // 修正：フォームページへの遷移
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A0C6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'お問い合わせはこちら',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // FAQアイテムのウィジェット
  Widget _buildFAQItem(FAQModel item) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FAQDetailPage(faq: item),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ジャンルアイコン
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getGenreColor(item.genre),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _getGenreIcon(item.genre),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 質問内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.question,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.genre,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // 矢印アイコン
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // ジャンルに応じた色を返す
  Color _getGenreColor(String genre) {
    switch (genre) {
      case 'サービスについて':
        return const Color(0xFF00A0C6);
      case 'アカウントについて':
        return const Color(0xFF4CAF50);
      case 'アプリについて':
        return const Color(0xFF9C27B0);
      case 'ビジネス連携':
        return const Color(0xFFFF9800);
      case 'お問い合わせ':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF607D8B);
    }
  }

  // ジャンルに応じたアイコンを返す
  IconData _getGenreIcon(String genre) {
    switch (genre) {
      case 'サービスについて':
        return Icons.info_outline;
      case 'アカウントについて':
        return Icons.account_circle;
      case 'アプリについて':
        return Icons.smartphone;
      case 'ビジネス連携':
        return Icons.business;
      case 'お問い合わせ':
        return Icons.contact_support;
      default:
        return Icons.help_outline;
    }
  }
}

// FAQ詳細ページ（修正済み）
class FAQDetailPage extends StatefulWidget {
  final FAQModel faq;

  const FAQDetailPage({super.key, required this.faq});

  @override
  State<FAQDetailPage> createState() => _FAQDetailPageState();
}

class _FAQDetailPageState extends State<FAQDetailPage> {
  bool _hasRated = false;
  bool _isCheckingRating = true;

  @override
  void initState() {
    super.initState();
    _checkUserRating();
  }

  // ユーザーが既に評価済みかどうかをチェック
  Future<void> _checkUserRating() async {
    final hasRated = await FAQRatingService.hasUserRated(widget.faq.id);
    setState(() {
      _hasRated = hasRated;
      _isCheckingRating = false;
    });
  }

  // 評価を送信
  Future<void> _submitRating(bool isHelpful) async {
    // ユーザー認証を確認
    final user = await FAQRatingService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('評価の送信に失敗しました。もう一度お試しください。'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // 評価を保存
    final success = await FAQRatingService.saveRating(widget.faq.id, isHelpful);

    if (mounted) {
      if (success) {
        setState(() {
          _hasRated = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHelpful ? 'ご意見をありがとうございます' : 'ご意見をありがとうございます。今後の改善に役立てさせていただきます。'),
            duration: const Duration(seconds: 3),
          ),
        );

        // 「いいえ」の場合はお問い合わせフォームへの遷移を提案
        if (!isHelpful) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _showContactFormDialog();
            }
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('評価の送信に失敗しました。もう一度お試しください。'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // お問い合わせフォームへの案内ダイアログ
  void _showContactFormDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('追加のサポートが必要ですか？'),
          content: const Text('お問い合わせフォームから詳細なご質問やご要望をお送りいただけます。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('いいえ'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToContactForm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A0C6),
                foregroundColor: Colors.white,
              ),
              child: const Text('お問い合わせフォームへ'),
            ),
          ],
        );
      },
    );
  }

  // テキストをクリップボードにコピー
  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('コピーしました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // お問い合わせフォームへの遷移
  void _navigateToContactForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QAFormPage(
          initialGenre: widget.faq.genre, // FAQ詳細のジャンルを渡す
        ),
      ),
    );
  }

  // ジャンルに応じた色を返す
  Color _getGenreColor(String genre) {
    switch (genre) {
      case 'サービスについて':
        return const Color(0xFF00A0C6);
      case 'アカウントについて':
        return const Color(0xFF4CAF50);
      case 'アプリについて':
        return const Color(0xFF9C27B0);
      case 'ビジネス連携':
        return const Color(0xFFFF9800);
      case 'お問い合わせ':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF607D8B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.faq.title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          // メニューボタン
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {
              if (value == 'copy') {
                _copyToClipboard(context, '${widget.faq.question}\n\n${widget.faq.answer}');
              } else if (value == 'share') {
                Share.share('${widget.faq.question}\n\n${widget.faq.answer}');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy',
                child: Text('テキストをコピー'),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Text('共有する'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ジャンルタグ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getGenreColor(widget.faq.genre).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.faq.genre,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getGenreColor(widget.faq.genre),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 質問
              Text(
                widget.faq.question,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),

              // 回答
              Text(
                widget.faq.answer,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 32),

              // 更新日時
              Text(
                '最終更新: ${_formatTimestamp(widget.faq.lastUpdated)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 40),

              // 問い合わせボタン
              const Divider(),
              const SizedBox(height: 20),

              // 評価セクション
              if (_isCheckingRating)
                const Center(child: CircularProgressIndicator())
              else if (_hasRated)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '評価いただき、ありがとうございました',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'この回答は役に立ちましたか？',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _submitRating(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A0C6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('はい'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _submitRating(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF00A0C6),
                              side: const BorderSide(color: Color(0xFF00A0C6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('いいえ'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Timestamp形式を読みやすい日付に変換
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year年$month月$day日';
  }
}