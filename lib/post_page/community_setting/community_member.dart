import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MemberInfoWidget extends StatelessWidget {
  final String communityId;

  const MemberInfoWidget({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'メンバー',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<bool>(
        // コミュニティの存在確認
        future: _validateCommunity(communityId),
        builder: (context, validateSnapshot) {
          if (validateSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (validateSnapshot.hasError) {
            return _buildErrorWidget(
              context,
              'コミュニティの確認中にエラーが発生しました',
              validateSnapshot.error.toString(),
            );
          }

          if (!validateSnapshot.data!) {
            return _buildErrorWidget(
              context,
              'コミュニティが見つかりません',
              'IDを確認してください',
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('community_list')
                .doc(communityId)
                .collection('add_member')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorWidget(
                  context,
                  'メンバー情報の取得中にエラーが発生しました',
                  snapshot.error.toString(),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = snapshot.data?.docs ?? [];

              if (members.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'メンバーが見つかりません',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return _buildMemberList(members);
            },
          );
        },
      ),
    );
  }

  // コミュニティの存在確認
  Future<bool> _validateCommunity(String communityId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('community_list')
          .doc(communityId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error validating community: $e');
      rethrow;
    }
  }

  // エラー表示用ウィジェット
  Widget _buildErrorWidget(
    BuildContext context,
    String message,
    String details,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              details,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('戻る'),
            ),
          ],
        ),
      ),
    );
  }

  // メンバーリスト表示用ウィジェット
  Widget _buildMemberList(List<QueryDocumentSnapshot> members) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final memberData = members[index].data() as Map<String, dynamic>;

        // null チェックを追加
        final nickname = memberData['nickname'] as String? ?? '名前なし';
        final iconUrl = memberData['iconUrl'] as String?;
        final authority = memberData['authority'] as String?;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey[200],
                  backgroundImage:
                      iconUrl != null ? NetworkImage(iconUrl) : null,
                  onBackgroundImageError: (exception, stackTrace) {
                    print('Error loading image: $exception');
                  },
                  child: iconUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 25,
                          color: Colors.grey,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (authority != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          authority,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
