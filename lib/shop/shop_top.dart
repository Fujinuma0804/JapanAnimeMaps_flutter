import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// カテゴリーのデータモデル
class ShopCategory {
  final String id;
  final String name;
  final DateTime createdAt;

  ShopCategory({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory ShopCategory.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) {
        return DateTime.now();
      }
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      }
      throw Exception('Invalid date format: $value');
    }

    return ShopCategory(
      id: id,
      name: map['name'] as String? ?? '',
      createdAt: parseDateTime(map['createdAt']),
    );
  }
}

// カテゴリーデータを取得する関数
Future<List<ShopCategory>> fetchCategories() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('categories')
        .orderBy('createdAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      print('No categories found');
      return [];
    }

    List<ShopCategory> categories = [];
    for (var doc in snapshot.docs) {
      try {
        final data = doc.data();
        print('Processing category document: ${doc.id}');
        print('Category data: $data');

        // nameフィールドが存在する場合のみ追加
        if (data.containsKey('name')) {
          categories.add(ShopCategory.fromMap(doc.id, data));
        } else {
          print('Skipping category ${doc.id} due to missing name field');
        }
      } catch (e) {
        print('Error processing category ${doc.id}: $e');
        continue;
      }
    }

    return categories;
  } catch (e) {
    print('Error fetching categories: $e');
    return [];
  }
}

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
      print('Error parsing ShopEvent: $e');
      print('Raw data: $map');
      rethrow;
    }
  }
}

class ShopHomeScreen extends StatelessWidget {
  const ShopHomeScreen({Key? key}) : super(key: key);

  // カテゴリーデータを取得する関数
  Future<List<ShopCategory>> fetchCategories() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('categories').get();

      return snapshot.docs
          .map((doc) => ShopCategory.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  Future<List<ShopEvent>> fetchShopEvents() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('shop_event').get();

      if (snapshot.docs.isEmpty) {
        print('No documents found in shop_event collection');
        return [];
      }

      List<ShopEvent> events = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          print('Processing document: ${doc.id}');
          print('Document data: $data');

          if (data.containsKey('images') &&
              data.containsKey('isActive') &&
              data.containsKey('link')) {
            events.add(ShopEvent.fromMap(data));
          } else {
            print('Skipping document ${doc.id} due to missing required fields');
          }
        } catch (e) {
          print('Error processing document ${doc.id}: $e');
          continue;
        }
      }

      return events;
    } catch (e) {
      print('Error fetching shop events: $e');
      rethrow;
    }
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(seconds: 2));
  }

  Widget _buildCarousel(List<ShopEvent> activeEvents) {
    if (activeEvents.isEmpty) return const SizedBox.shrink();

    return CarouselSlider(
      options: CarouselOptions(
        height: 200.0,
        autoPlay: true,
        aspectRatio: 16 / 9,
        enlargeCenterPage: true,
        autoPlayInterval: const Duration(seconds: 5),
      ),
      items: activeEvents.map((event) {
        return Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () async {
                try {
                  final uri = Uri.parse(event.link);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    print('Could not launch ${event.link}');
                  }
                } catch (e) {
                  print('Error launching URL: $e');
                }
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: NetworkImage(event.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        cursorColor: Colors.black,
                        decoration: InputDecoration(
                          hintText: '商品をさがす（アニメ・キャラクターなど）',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(
                                color: Colors.black, width: 2.0),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    ),

                    // Banner Carousel
                    FutureBuilder<List<ShopEvent>>(
                      future: fetchShopEvents(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const SizedBox.shrink();
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final now = DateTime.now();
                        final activeEvents = snapshot.data!
                            .where((event) =>
                                event.isActive &&
                                now.isAfter(event.startDate) &&
                                now.isBefore(event.endDate))
                            .toList();

                        return _buildCarousel(activeEvents);
                      },
                    ),

                    // Categories Section
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          FutureBuilder<List<ShopCategory>>(
                            future: fetchCategories(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Center(
                                  child: Text('カテゴリーが見つかりません'),
                                );
                              }

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.0,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final category = snapshot.data![index];
                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        // カテゴリーがタップされたときの処理
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              category.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Fixed bottom bar
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.black,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite_border,
                              color: Colors.black,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'お気に入り',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.black,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.black,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'カート',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.black,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.black,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
