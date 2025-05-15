import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 質問と回答の構造体
class QAItem {
  final String id;
  final String question;
  final String answer;
  final bool isPremium;

  QAItem({
    required this.id,
    required this.question,
    required this.answer,
    this.isPremium = false,
  });

  factory QAItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return QAItem(
      id: doc.id,
      question: data['question'] ?? '',
      answer: data['answer'] ?? '',
      isPremium: data['isPremium'] ?? false,
    );
  }
}

// QA詳細ページのテンプレート
class QADetailPage extends StatefulWidget {
  final String categoryId;
  final String categoryTitle;
  final IconData categoryIcon;
  final Color categoryColor;

  const QADetailPage({
    Key? key,
    required this.categoryId,
    required this.categoryTitle,
    required this.categoryIcon,
    this.categoryColor = const Color(0xFF00A0C6),
  }) : super(key: key);

  @override
  State<QADetailPage> createState() => _QADetailPageState();
}

class _QADetailPageState extends State<QADetailPage> {
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  bool isPremiumUser = false;
  List<QAItem> qaItems = [];
  List<QAItem> filteredItems = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    fetchQAData();
    checkPremiumStatus();
  }

  // プレミアムステータスの確認
  Future<void> checkPremiumStatus() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
            .instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data()?['isPremium'] != null) {
          setState(() {
            isPremiumUser = userDoc.data()?['isPremium'] ?? false;
          });
        }
      }
    } catch (e) {
      print('Error checking premium status: $e');
    }
  }

  // Firestoreからカテゴリに対応するQ&Aデータを取得
  Future<void> fetchQAData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('qa_categories')
          .doc(widget.categoryId)
          .collection('questions')
          .get();

      setState(() {
        qaItems = snapshot.docs.map((doc) => QAItem.fromFirestore(doc)).toList();
        filteredItems = List.from(qaItems);
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching QA data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // 検索テキストに基づいてアイテムをフィルタリングする関数
  void _filterItems() {
    setState(() {
      if (_searchController.text.isEmpty) {
        filteredItems = List.from(qaItems);
      } else {
        filteredItems = qaItems
            .where((item) =>
        item.question.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            item.answer.toLowerCase().contains(_searchController.text.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
            color: const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(20),
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
            onSubmitted: (value) {
              print('検索実行: $value');
            },
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // カテゴリヘッダー
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: widget.categoryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.categoryIcon,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.categoryTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Q&Aリスト
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
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: filteredItems.length,
                separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1),
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return _buildQAItem(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQAItem(QAItem item) {
    bool isAccessible = !item.isPremium || (item.isPremium && isPremiumUser);

    return ExpansionTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.question,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isAccessible ? Colors.black : Colors.black54,
              ),
            ),
          ),
          if (item.isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber[700],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'プレミアム',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: isAccessible
              ? Text(
            item.answer,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'この回答はプレミアム会員限定です。',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // プレミアム会員登録ページへの遷移
                  print('プレミアム会員登録へ');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('プレミアム会員になる'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}