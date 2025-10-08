import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:parts/shiori/shiori_bottom_budget.dart';

class ShioriBottomMember extends StatefulWidget {
  const ShioriBottomMember({Key? key}) : super(key: key);

  @override
  State<ShioriBottomMember> createState() => _ShioriBottomMemberState();
}

class _ShioriBottomMemberState extends State<ShioriBottomMember> {
  String? selectedMemberCount;
  String? selectedRelationship;

  // 人数オプション
  final List<String> memberCountOptions = [
    '人数 - 未定',
    '1人',
    '2人',
    '3人',
    '4人',
    '5人',
    '6人',
    '7人',
    '8人',
    '9人',
    '10人以上',
  ];

  // 間柄オプション
  final List<String> relationshipOptions = [
    '1人旅',
    '夫婦・カップル',
    '家族(子供連れ)',
    '家族(大人のみ)',
    '友人',
    '同僚',
    'その他',
  ];

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
                    color: Colors.grey,
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
              'メンバー',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 32),

            // 人数セクション
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '人数',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const Text(
                  '任意',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: () {
                _showMemberCountPicker();
              },
              child: Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  selectedMemberCount ?? '人数 - 未定',
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedMemberCount != null
                        ? Colors.black
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 間柄セクション
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '間柄',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const Text(
                  '任意',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: () {
                _showRelationshipPicker();
              },
              child: Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedRelationship ?? '間柄 - 未定',
                      style: TextStyle(
                        fontSize: 16,
                        color: selectedRelationship != null
                            ? Colors.black
                            : Colors.grey[600],
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
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
                    MaterialPageRoute(builder: (context) => ShioriBudgetScreen()),
                  );
                  // 次の画面に進む処理
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

  void _showMemberCountPicker() {
    int selectedIndex = 0;
    if (selectedMemberCount != null) {
      selectedIndex = memberCountOptions.indexOf(selectedMemberCount!);
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            // ヘッダー部分（キャンセル・完了ボタン）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator.resolveFrom(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'キャンセル',
                      style: TextStyle(
                        color: CupertinoColors.systemRed,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        selectedMemberCount = memberCountOptions[selectedIndex];
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      '完了',
                      style: TextStyle(
                        color: CupertinoColors.activeBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ピッカー部分
            Expanded(
              child: CupertinoPicker(
                backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
                itemExtent: 44.0,
                scrollController: FixedExtentScrollController(
                  initialItem: selectedIndex,
                ),
                onSelectedItemChanged: (int value) {
                  selectedIndex = value;
                },
                children: memberCountOptions.map((String option) {
                  return Center(
                    child: Text(
                      option,
                      style: const TextStyle(
                        fontSize: 18,
                        color: CupertinoColors.label,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRelationshipPicker() {
    int selectedIndex = 0;
    if (selectedRelationship != null) {
      selectedIndex = relationshipOptions.indexOf(selectedRelationship!);
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            // ヘッダー部分（キャンセル・完了ボタン）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator.resolveFrom(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'キャンセル',
                      style: TextStyle(
                        color: CupertinoColors.systemRed,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        selectedRelationship = relationshipOptions[selectedIndex];
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      '完了',
                      style: TextStyle(
                        color: CupertinoColors.activeBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ピッカー部分
            Expanded(
              child: CupertinoPicker(
                backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
                itemExtent: 44.0,
                scrollController: FixedExtentScrollController(
                  initialItem: selectedIndex,
                ),
                onSelectedItemChanged: (int value) {
                  selectedIndex = value;
                },
                children: relationshipOptions.map((String option) {
                  return Center(
                    child: Text(
                      option,
                      style: const TextStyle(
                        fontSize: 18,
                        color: CupertinoColors.label,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

        ),
      ),
    );
  }
}