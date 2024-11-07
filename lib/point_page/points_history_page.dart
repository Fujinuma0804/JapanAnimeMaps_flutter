import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PointsHistoryPage extends StatefulWidget {
  const PointsHistoryPage({super.key, required String userId});

  @override
  State<PointsHistoryPage> createState() => _PointsHistoryPageState();
}

class _PointsHistoryPageState extends State<PointsHistoryPage> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
  }

  @override
  Widget build(BuildContext context) {
    const String userId = 'testUser';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ポイント獲得・交換',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00008b),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('correctHistory') // コレクション名を変更
                  .where('timestamp',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate),
                      isLessThanOrEqualTo: Timestamp.fromDate(
                          _endDate.add(const Duration(days: 1))))
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('エラーが発生しました'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('再読み込み'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFF00008b),
                    ),
                  );
                }

                final documents = snapshot.data?.docs ?? [];
                if (documents.isEmpty) {
                  return const Center(
                    child: Text('この期間の履歴はありません'),
                  );
                }

                // 月ごとにグループ化
                final groupedDocs = <String, List<QueryDocumentSnapshot>>{};
                for (var doc in documents) {
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = (data['timestamp'] as Timestamp).toDate();
                  final monthKey = DateFormat('yyyy年 MM月').format(timestamp);

                  groupedDocs.putIfAbsent(monthKey, () => []);
                  groupedDocs[monthKey]!.add(doc);
                }

                return ListView(
                  children: groupedDocs.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMonthHeader(entry.key),
                        ...entry.value.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final timestamp =
                              (data['timestamp'] as Timestamp).toDate();
                          return _buildHistoryItem(
                            correctCount: 1, // correctCountは1ずつ増加
                            timestamp: timestamp,
                            quizTitle:
                                data['quizTitle'] ?? '問題', // クイズのタイトルがあれば表示
                          );
                        }),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(String month) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Text(
        month,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHistoryItem({
    required int correctCount,
    required DateTime timestamp,
    required String quizTitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '+${correctCount}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      ' 正解',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  quizTitle,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('HH時mm分').format(timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('yyyy/MM/dd').format(timestamp),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
