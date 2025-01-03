import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Product model
class Product {
  final String id;
  final String name;
  final String brand;
  final String imageUrl;
  final double price;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.price,
    required this.createdAt,
  });

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    try {
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

      return Product(
        id: id,
        name: map['name'] as String? ?? '',
        brand: map['brand'] as String? ?? '',
        imageUrl: map['imageUrl'] as String? ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        createdAt: parseDateTime(map['createdAt']),
      );
    } catch (e) {
      print('Error creating Product from map: $e');
      print('Map data: $map');
      rethrow;
    }
  }
}

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
    try {
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
    } catch (e) {
      print('Error creating ShopCategory from map: $e');
      print('Map data: $map');
      rethrow;
    }
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
      print('Error creating ShopEvent from map: $e');
      print('Map data: $map');
      rethrow;
    }
  }
}

// Product Grid Widget
class ProductGridSection extends StatelessWidget {
  final String title;
  final String viewAllText;
  final List<Product> products;

  const ProductGridSection({
    Key? key,
    required this.title,
    required this.viewAllText,
    required this.products,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Handle view all action
                },
                child: Text(
                  viewAllText,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(product: product);
          },
        ),
      ],
    );
  }
}

// Individual Product Card
class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return const Center(
                    child:
                        Icon(Icons.error_outline, size: 40, color: Colors.red),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.brand,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${product.price.toStringAsFixed(0)}(税込)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShopHomeScreen extends StatelessWidget {
  const ShopHomeScreen({Key? key}) : super(key: key);

  // カテゴリーごとの商品を取得する関数
  Future<Map<ShopCategory, List<Product>>> fetchProductsByCategory() async {
    try {
      print('Starting fetchProductsByCategory');
      final categoriesSnapshot =
          await FirebaseFirestore.instance.collection('categories').get();

      print('Retrieved ${categoriesSnapshot.docs.length} categories');

      if (categoriesSnapshot.docs.isEmpty) {
        print('No categories found');
        return {};
      }

      final Map<ShopCategory, List<Product>> categoryProducts = {};

      for (var categoryDoc in categoriesSnapshot.docs) {
        try {
          print('Processing category: ${categoryDoc.id}');
          final category =
              ShopCategory.fromMap(categoryDoc.id, categoryDoc.data());
          print('Category parsed: ${category.name}');

          // シンプルなクエリでプロダクトを取得
          final productsSnapshot = await FirebaseFirestore.instance
              .collection('products')
              .where('categoryId', isEqualTo: category.id)
              .get();

          print(
              'Retrieved ${productsSnapshot.docs.length} products for category ${category.name}');

          if (productsSnapshot.docs.isEmpty) {
            print('No products found for category ${category.name}');
            continue;
          }

          // メモリ内でソートと制限を行う
          final products = productsSnapshot.docs
              .map((doc) {
                try {
                  return Product.fromMap(doc.id, doc.data());
                } catch (e) {
                  print('Error parsing product ${doc.id}: $e');
                  return null;
                }
              })
              .whereType<Product>()
              .toList()
            ..sort(
                (a, b) => b.createdAt.compareTo(a.createdAt)); // createdAtでソート

          // 最新の4件を取得
          final limitedProducts = products.take(4).toList();

          if (limitedProducts.isNotEmpty) {
            print(
                'Added ${limitedProducts.length} products for category ${category.name}');
            categoryProducts[category] = limitedProducts;
          }
        } catch (e) {
          print('Error processing category ${categoryDoc.id}: $e');
          continue;
        }
      }

      print(
          'Finished processing all categories. Total categories with products: ${categoryProducts.length}');
      return categoryProducts;
    } catch (e, stackTrace) {
      print('Error fetching products by category: $e');
      print('Stack trace: $stackTrace');
      return {};
    }
  }

  Future<List<ShopEvent>> fetchShopEvents() async {
    try {
      print('Starting fetchShopEvents');
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
          print('Processing event document: ${doc.id}');
          print('Event data: $data');

          if (data.containsKey('images') &&
              data.containsKey('isActive') &&
              data.containsKey('link')) {
            events.add(ShopEvent.fromMap(data));
          } else {
            print(
                'Skipping event document ${doc.id} due to missing required fields');
          }
        } catch (e) {
          print('Error processing event document ${doc.id}: $e');
          continue;
        }
      }

      print('Finished processing events. Total events: ${events.length}');
      return events;
    } catch (e, stackTrace) {
      print('Error fetching shop events: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _onRefresh() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      print('Refresh completed');
    } catch (e) {
      print('Error during refresh: $e');
    }
  }

  Widget _buildCarousel(List<ShopEvent> activeEvents) {
    if (activeEvents.isEmpty) {
      print('No active events to display in carousel');
      return const SizedBox.shrink();
    }

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
                    onError: (error, stackTrace) {
                      print('Error loading carousel image: $error');
                    },
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Section
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

                    // Event Section
                    FutureBuilder<List<ShopEvent>>(
                      future: fetchShopEvents(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          print('Error in events: ${snapshot.error}');
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child:
                                  Text('イベントの読み込みに失敗しました: ${snapshot.error}'),
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          print('No events data available');
                          return const SizedBox.shrink();
                        }

                        final now = DateTime.now();
                        final activeEvents = snapshot.data!
                            .where((event) =>
                                event.isActive &&
                                now.isAfter(event.startDate) &&
                                now.isBefore(event.endDate))
                            .toList();

                        print('Active events: ${activeEvents.length}');
                        return _buildCarousel(activeEvents);
                      },
                    ),

                    // Categories and Products Section
                    FutureBuilder<Map<ShopCategory, List<Product>>>(
                      future: fetchProductsByCategory(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          print('Error in categories: ${snapshot.error}');
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child:
                                  Text('カテゴリーの読み込みに失敗しました: ${snapshot.error}'),
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          print('No category data available');
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text('カテゴリーが見つかりませんでした'),
                            ),
                          );
                        }

                        final categoryEntries = snapshot.data!.entries.toList();
                        print(
                            'Number of categories to display: ${categoryEntries.length}');

                        return Column(
                          children: categoryEntries.map((entry) {
                            final category = entry.key;
                            final products = entry.value;

                            print(
                                'Processing category ${category.name} with ${products.length} products');

                            if (products.isEmpty) {
                              print(
                                  'No products for category ${category.name}');
                              return const SizedBox.shrink();
                            }

                            return Column(
                              children: [
                                ProductGridSection(
                                  title: category.name,
                                  viewAllText: 'すべて見る',
                                  products: products,
                                ),
                                const SizedBox(height: 16), // カテゴリー間のスペース
                              ],
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
                      onTap: () {
                        print('Favorite button tapped');
                      },
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
                      onTap: () {
                        print('Cart button tapped');
                      },
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
}
