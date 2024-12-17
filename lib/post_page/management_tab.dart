import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'community_operation_tab.dart';

// 運営タブのコンテンツを管理するウィジェット
class ManagementTab extends StatelessWidget {
  const ManagementTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community_operation_notification')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('エラーが発生しました: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // お知らせが存在しない場合は現在の表示を使用
        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/not_found.png',
                  width: 500,
                  height: 500,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }

        // お知らせが存在する場合はOperationTabContentを使用
        return const OperationTabContent();
      },
    );
  }
}
