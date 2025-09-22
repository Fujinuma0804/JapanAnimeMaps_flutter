import 'package:flutter/material.dart';
import 'package:parts/shiori/shiori_bottom_tripname.dart';

class ShioriBudgetScreen extends StatefulWidget {
  const ShioriBudgetScreen({Key? key}) : super(key: key);

  @override
  State<ShioriBudgetScreen> createState() => _ShioriBudgetScreenState();
}

class _ShioriBudgetScreenState extends State<ShioriBudgetScreen> {
  int budgetRangeIndex = 2; // 初期値は10000円〜（インデックス2）

  // 予算範囲の定義
  final List<Map<String, dynamic>> budgetRanges = [
    {'label': '〜¥5,000', 'value': 3000, 'max': 5000},
    {'label': '¥5,000〜', 'value': 7500, 'max': 10000},
    {'label': '¥10,000〜', 'value': 15000, 'max': 20000},
    {'label': '¥20,000〜', 'value': 35000, 'max': 50000},
    {'label': '¥50,000〜', 'value': 75000, 'max': 100000},
  ];

  // 現在選択されている予算範囲のラベルを取得
  String getCurrentBudgetLabel() {
    return budgetRanges[budgetRangeIndex]['label'];
  }

  // 予算を適切な表示形式に変換
  String formatBudget(double value) {
    if (value >= 10000) {
      double manValue = value / 10000;
      if (manValue == manValue.toInt()) {
        return '${manValue.toInt()}万円';
      } else {
        return '${manValue.toStringAsFixed(1)}万円';
      }
    } else {
      return '${value.toInt()}円';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '新規作成',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              // スキップ処理
            },
            child: const Text(
              'スキップ',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              '次の旅行について教えてください',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 40),

            // プログレスインジケーター
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ECDC4), // ターコイズ色
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            const Text(
              '予算',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              '1人分の1泊あたりの予算を入力',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 60),

            // 予算表示
            Center(
              child: Text(
                getCurrentBudgetLabel(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 60),

            // スライダー
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFFF6B9D),
                inactiveTrackColor: Colors.grey[300],
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 16.0,
                  elevation: 4.0,
                ),
                overlayColor: const Color(0xFFFF6B9D).withOpacity(0.2),
                trackHeight: 6.0,
              ),
              child: Slider(
                value: budgetRangeIndex.toDouble(),
                min: 0,
                max: (budgetRanges.length - 1).toDouble(),
                divisions: budgetRanges.length - 1,
                onChanged: (double value) {
                  setState(() {
                    budgetRangeIndex = value.round();
                  });
                },
              ),
            ),

            const SizedBox(height: 20),

            // 最小・最大値表示
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  budgetRanges.first['label'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  budgetRanges.last['label'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            const Spacer(),

            // 次へボタン
            Container(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ShioriTripNameScreen()),
                  );
                  // 次の画面に進む処理
                  print('選択された予算範囲: ${getCurrentBudgetLabel()}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B9D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '次へ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}