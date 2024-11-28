// DraftsListクラスの修正部分
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DraftsList extends StatelessWidget {
  final User currentUser;
  final Function(DocumentSnapshot) onDraftSelected;
  static const String tag = 'DraftsList';

  const DraftsList({
    Key? key,
    required this.currentUser,
    required this.onDraftSelected,
  }) : super(key: key);

  void _logError(String message, dynamic error) {
    print('[$tag] Error: $message');
    print('[$tag] Error details: $error');
  }

  void _logInfo(String message) {
    print('[$tag] Info: $message');
  }

  @override
  Widget build(BuildContext context) {
    _logInfo('Building DraftsList for user: ${currentUser.uid}');

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '下書き一覧',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Flexible(
            child: StreamBuilder<QuerySnapshot>(
              // クエリを使用せずにコレクション全体を取得
              stream:
                  FirebaseFirestore.instance.collection('drafts').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  _logError('StreamBuilder error', snapshot.error);
                  return const Center(
                    child: Text('エラーが発生しました'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('下書きはありません'),
                  );
                }

                // 現在のユーザーの下書きのみをフィルタリング
                final userDrafts = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['userId'] == currentUser.uid;
                }).toList();

                // フィルタリング後のリストが空の場合
                if (userDrafts.isEmpty) {
                  return const Center(
                    child: Text('下書きはありません'),
                  );
                }

                // 日付でソート
                userDrafts.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTimestamp = aData['createdAt'] as Timestamp?;
                  final bTimestamp = bData['createdAt'] as Timestamp?;
                  if (aTimestamp == null || bTimestamp == null) return 0;
                  return bTimestamp.compareTo(aTimestamp); // 降順
                });

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: userDrafts.length,
                  itemBuilder: (context, index) {
                    final draft = userDrafts[index];
                    final data = draft.data() as Map<String, dynamic>;

                    try {
                      final mediaUrls =
                          List<String>.from(data['mediaUrls'] ?? []);
                      final timestamp = data['createdAt'] as Timestamp?;
                      final createdAt = timestamp?.toDate() ?? DateTime.now();

                      return Dismissible(
                        key: Key(draft.id),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          try {
                            FirebaseFirestore.instance
                                .collection('drafts')
                                .doc(draft.id)
                                .delete()
                                .then((_) {
                              _logInfo('Draft deleted: ${draft.id}');
                            }).catchError((error) {
                              _logError('Delete error', error);
                            });
                          } catch (e) {
                            _logError('Delete operation error', e);
                          }
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            data['text'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${createdAt.year}/${createdAt.month}/${createdAt.day} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: mediaUrls.isNotEmpty
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: mediaUrls.first,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) {
                                          _logError('Image load error', error);
                                          return const Icon(Icons.error);
                                        },
                                      ),
                                    ),
                                    if (mediaUrls.length > 1)
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '+${mediaUrls.length - 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : null,
                          onTap: () => onDraftSelected(draft),
                        ),
                      );
                    } catch (e) {
                      _logError('Error building draft item', e);
                      return const ListTile(
                        title: Text('下書きの読み込みに失敗しました'),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
