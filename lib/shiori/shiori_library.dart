import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:parts/shiori/shiori_bottom_where.dart';

class ShioriLibrary extends StatefulWidget {
  const ShioriLibrary({super.key});

  @override
  State<ShioriLibrary> createState() => _ShioriLibraryState();
}

class _ShioriLibraryState extends State<ShioriLibrary> {
  void _showCreateOptionsModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text(
            'どちらを作成しますか？',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.black,
            ),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ShioriBottomWhere()),
                );
                // 旅のしおり作成処理
              },
              child: const Text(
                '旅のしおり',
                style: TextStyle(
                  fontSize: 18,
                  color: CupertinoColors.systemBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                // スポットリスト作成処理
              },
              child: const Text(
                'スポットリスト（簡易版）',
                style: TextStyle(
                  fontSize: 18,
                  color: CupertinoColors.systemBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'キャンセル',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.systemBlue,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16.0),
          child: const Text(
            'Myライブラリ',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        leadingWidth: 150, // テキストの幅に応じて調整
        actions: [
          IconButton(
            onPressed: _showCreateOptionsModal,
            icon: const Icon(
              Icons.add,
              color: Color(0xFF00008b),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(
            height: 20,
          ),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: Container(
              color: Colors.red,
            ),
          ),
          const SizedBox(
            height: 20,
          ),
        ],
      )
    );
  }
}