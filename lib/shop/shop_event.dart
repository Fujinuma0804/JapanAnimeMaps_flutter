import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// イベントデータモデル
class ShopEvent {
  final DateTime createdAt;
  final DateTime endDate;
  final String imageUrl;
  final bool isActive;
  final String link;
  final DateTime startDate;

  ShopEvent({
    required this.createdAt,
    required this.endDate,
    required this.imageUrl,
    required this.isActive,
    required this.link,
    required this.startDate,
  });

  factory ShopEvent.fromMap(Map<String, dynamic> map) {
    try {
      DateTime parseDateTime(dynamic value) {
        if (value == null) {
          return DateTime.now();
        }
        if (value is Timestamp) {
          return value.toDate();
        } else if (value is String) {
          return value.contains('UTC')
              ? DateTime.parse(value)
              : DateTime.parse(value + ' UTC+9');
        }
        throw Exception('Invalid date format: $value');
      }

      final images = map['images'];
      final imageUrl = images != null && images is List && images.isNotEmpty
          ? images[0] as String
          : '';

      return ShopEvent(
        createdAt: parseDateTime(map['createdAt']),
        endDate: parseDateTime(map['endDate']),
        imageUrl: imageUrl,
        isActive: map['isActive'] as bool? ?? false,
        link: map['link'] as String? ?? '',
        startDate: parseDateTime(map['startDate']),
      );
    } catch (e) {
      print('Error creating ShopEvent from map: $e');
      print('Map data: $map');
      rethrow;
    }
  }
}

// 共通のイベント情報カード
class CommonEventCard extends StatelessWidget {
  const CommonEventCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.event, size: 48, color: Colors.blue),
            const SizedBox(height: 8),
            const Text(
              'イベント情報',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ここはイベントの共通情報を表示します',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // ボタンのアクション
              },
              child: const Text('詳細を見る'),
            ),
          ],
        ),
      ),
    );
  }
}

// Firestoreからイベントを取得して表示するカード
class ShopEventCard extends StatelessWidget {
  const ShopEventCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('isActive', isEqualTo: true)
          .orderBy('startDate', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return FixedShopEventDisplay(
            event: ShopEvent(
              createdAt: DateTime.now(),
              endDate: DateTime.now(),
              imageUrl: '',
              isActive: false,
              link: '',
              startDate: DateTime.now(),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return FixedShopEventDisplay(
            event: ShopEvent(
              createdAt: DateTime.now(),
              endDate: DateTime.now(),
              imageUrl: '',
              isActive: false,
              link: '',
              startDate: DateTime.now(),
            ),
          );
        }

        final eventData = snapshot.data!.docs[0].data() as Map<String, dynamic>;
        final event = ShopEvent.fromMap(eventData);
        return FixedShopEventDisplay(event: event);
      },
    );
  }
}

// 固定表示用のウィジェット
class FixedShopEventDisplay extends StatelessWidget {
  final ShopEvent event;

  const FixedShopEventDisplay({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 200,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailPage(event: event),
            ),
          );
        },
        child: Card(
          child: Column(
            children: [
              Expanded(
                child: Image.network(
                  event.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.error),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${event.startDate.year}/${event.startDate.month}/${event.startDate.day}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (event.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '開催中',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// イベント詳細ページ
class EventDetailPage extends StatelessWidget {
  final ShopEvent event;

  const EventDetailPage({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('イベント詳細'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              event.imageUrl,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'イベント期間',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${event.startDate.year}年${event.startDate.month}月${event.startDate.day}日 - '
                    '${event.endDate.year}年${event.endDate.month}月${event.endDate.day}日',
                  ),
                  const SizedBox(height: 16),
                  if (event.link.isNotEmpty)
                    ElevatedButton(
                      onPressed: () {
                        // リンクを開く処理をここに実装
                      },
                      child: const Text('詳細を見る'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// イベントページ（使用例）
class EventPage extends StatelessWidget {
  const EventPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('イベント情報'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: const [
            // 共通のイベント情報カード（Firebaseとは独立）
            CommonEventCard(),
            SizedBox(height: 16),
            // Firestoreからデータを取得するカード
            ShopEventCard(),
          ],
        ),
      ),
    );
  }
}
