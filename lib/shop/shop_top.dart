// ignore_for_file: avoid_print

import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parts/shop/shop_cart.dart';
import 'package:parts/shop/shop_event.dart';
import 'package:parts/shop/shop_product_detail.dart';
import 'package:parts/src/shop_top_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

// Product Model
class Product {
  final String id;
  final String name;
  final double price;
  final double costPrice;
  final String description;
  final List<String> imageUrls;
  final List<String> categories;
  final String officialUrl;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.costPrice,
    required this.description,
    required this.imageUrls,
    required this.categories,
    required this.officialUrl,
    required this.createdAt,
  });

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    try {
      DateTime parseDateTime(dynamic value) {
        if (value == null) return DateTime.now();
        if (value is Timestamp) return value.toDate();
        if (value is String) return DateTime.parse(value);
        throw Exception('Invalid date format: $value');
      }

      return Product(
        id: id,
        name: map['name'] as String? ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
        description: map['description'] as String? ?? '',
        imageUrls: List<String>.from(map['imageUrls'] ?? []),
        categories: List<String>.from(map['categories'] ?? []),
        officialUrl: map['officialUrl'] as String? ?? '',
        createdAt: parseDateTime(map['createdAt']),
      );
    } catch (e) {
      print('Error creating Product from map: $e');
      print('Map data: $map');
      rethrow;
    }
  }
}

// Static Carousel Item Model
class StaticCarouselItem {
  final String assetImagePath;
  final String routeName;
  final Map<String, dynamic>? arguments;

  StaticCarouselItem({
    required this.assetImagePath,
    required this.routeName,
    this.arguments,
  });
}

// Category Circle Model
class CategoryCircle {
  final String name;
  final String imageUrl;
  final String route;

  CategoryCircle({
    required this.name,
    required this.imageUrl,
    required this.route,
  });
}

// Square Item Model
class SquareItem {
  final String imageUrl;
  final String route;

  SquareItem({
    required this.imageUrl,
    required this.route,
  });
}

// Product Card Widget
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: Image.network(
                  product.imageUrls.isNotEmpty ? product.imageUrls[0] : '',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading image: $error');
                    return const Center(
                      child: Icon(Icons.error_outline, size: 40, color: Colors.red),
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
      ),
    );
  }
}

// Shop Home Screen
class ShopHomeScreen extends StatelessWidget {
  ShopHomeScreen({super.key});

  final List<StaticCarouselItem> staticItems = [
    StaticCarouselItem(
      assetImagePath: 'assets/images/not_found.png',
      routeName: '/product_purchase_agency',
    ),
  ];

  final List<SquareItem> squareItems = [
    SquareItem(
      imageUrl: 'assets/images/squares/new_items.jpg',
      route: '/new-items',
    ),
    SquareItem(
      imageUrl: 'assets/images/squares/ranking.jpg',
      route: '/ranking',
    ),
    SquareItem(
      imageUrl: 'assets/images/squares/sale.jpg',
      route: '/sale',
    ),
    SquareItem(
      imageUrl: 'assets/images/squares/limited.jpg',
      route: '/limited',
    ),
    SquareItem(
      imageUrl: 'assets/images/squares/limited.jpg',
      route: '/limited',
    ),
  ];

  final List<CategoryCircle> categoryCircles = [
    CategoryCircle(
      name: 'アニメ',
      imageUrl: 'assets/images/categories/anime.jpg',
      route: '/category/anime',
    ),
    CategoryCircle(
      name: 'ゲーム',
      imageUrl: 'assets/images/categories/games.jpg',
      route: '/category/games',
    ),
    CategoryCircle(
      name: 'コミック',
      imageUrl: 'assets/images/categories/comics.jpg',
      route: '/category/comics',
    ),
    CategoryCircle(
      name: 'フィギュア',
      imageUrl: 'assets/images/categories/figures.jpg',
      route: '/category/figures',
    ),
    CategoryCircle(
      name: 'コスプレ',
      imageUrl: 'assets/images/categories/cosplay.jpg',
      route: '/category/cosplay',
    ),
    CategoryCircle(
      name: 'コスプレ',
      imageUrl: 'assets/images/categories/cosplay.jpg',
      route: '/category/cosplay',
    ),CategoryCircle(
      name: 'コスプレ',
      imageUrl: 'assets/images/categories/cosplay.jpg',
      route: '/category/cosplay',
    ),
  ];

  Future<Map<String, List<Product>>> fetchProductsByCategory() async {
    try {
      print('Starting fetchProductsByCategory');

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .get();

      print('Retrieved ${productsSnapshot.docs.length} total products');

      final Map<String, List<Product>> productsByCategory = {};

      for (var doc in productsSnapshot.docs) {
        try {
          final product = Product.fromMap(doc.id, doc.data());

          for (String category in product.categories) {
            if (!productsByCategory.containsKey(category)) {
              productsByCategory[category] = [];
            }
            productsByCategory[category]!.add(product);
          }
        } catch (e) {
          print('Error processing product ${doc.id}: $e');
          continue;
        }
      }

      return productsByCategory;
    } catch (e, stackTrace) {
      print('Error in fetchProductsByCategory: $e');
      print('Stack trace: $stackTrace');
      return {};
    }
  }

  Future<List<ShopEvent>> fetchShopEvents() async {
    try {
      print('Starting fetchShopEvents');
      final snapshot = await FirebaseFirestore.instance.collection('shop_event').get();

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
            print('Skipping event document ${doc.id} due to missing required fields');
          }
        } catch (e) {
          print('Error processing event document ${doc.id}: $e');
          continue;
        }
      }

      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
    List<Widget> allCarouselItems = [];

    allCarouselItems.addAll(staticItems.map((item) {
      return Builder(
        builder: (BuildContext context) {
          return GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamed(
                item.routeName,
                arguments: item.arguments,
              );
            },
            child: Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: AssetImage(item.assetImagePath),
                  fit: BoxFit.cover,
                  onError: (error, stackTrace) {
                    print('Error loading static carousel image: $error');
                  },
                ),
              ),
            ),
          );
        },
      );
    }));

    allCarouselItems.addAll(activeEvents.map((event) {
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
    }));

    if (allCarouselItems.isEmpty) {
      print('No items to display in carousel');
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
      items: allCarouselItems,
    );
  }

  // Widget _buildCategoryCircles() {
  //   return Container(
  //     height: 100,
  //     margin: const EdgeInsets.only(top: 8.0),
  //     child: ListView.builder(
  //       scrollDirection: Axis.horizontal,
  //       padding: const EdgeInsets.symmetric(horizontal: 16.0),
  //       itemCount: categoryCircles.length,
  //       itemBuilder: (context, index) {
  //         return Padding(
  //           padding: const EdgeInsets.only(right: 16.0),
  //           child: Column(
  //             children: [
  //               GestureDetector(
  //                 onTap: () {
  //                   Navigator.pushNamed(
  //                     context,
  //                     categoryCircles[index].route,
  //                   );
  //                 },
  //                 child: Container(
  //                   width: 60,
  //                   height: 60,
  //                   decoration: BoxDecoration(
  //                     shape: BoxShape.circle,
  //                     border: Border.all(
  //                       color: Colors.grey[300]!,
  //                       width: 1,
  //                     ),
  //                   ),
  //                   child: ClipRRect(
  //                     borderRadius: BorderRadius.circular(30),
  //                     child: Image.asset(
  //                       categoryCircles[index].imageUrl,
  //                       fit: BoxFit.cover,
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //               const SizedBox(height: 8),
  //               Text(
  //                 categoryCircles[index].name,
  //                 style: const TextStyle(
  //                   fontSize: 12,
  //                   fontWeight: FontWeight.w500,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }

  // Widget _buildSquareItems() {
  //   return SizedBox(
  //     height: 70,
  //     child: ListView.builder(
  //       scrollDirection: Axis.horizontal,
  //       padding: const EdgeInsets.symmetric(horizontal: 16.0),
  //       itemCount: squareItems.length,
  //       itemBuilder: (context, index) {
  //         return Padding(
  //           padding: const EdgeInsets.only(right: 12.0),
  //           child: GestureDetector(
  //             onTap: () {
  //               Navigator.pushNamed(
  //                 context,
  //                 squareItems[index].route,
  //               );
  //             },
  //             child: Container(
  //               width: 75,
  //               decoration: BoxDecoration(
  //                 borderRadius: BorderRadius.circular(8),
  //                 border: Border.all(
  //                   color: Colors.grey[300]!,
  //                   width: 1,
  //                 ),
  //               ),
  //               child: Column(
  //                 children: [
  //                   Expanded(
  //                     child: ClipRRect(
  //                       borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
  //                       child: Image.asset(
  //                         squareItems[index].imageUrl,
  //                         width: double.infinity,
  //                         fit: BoxFit.cover,
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }

  // Widget _buildSquare2Items() {
  //   return SizedBox(
  //     height: 145,
  //     child: ListView.builder(
  //       scrollDirection: Axis.horizontal,
  //       padding: const EdgeInsets.symmetric(horizontal: 16.0),
  //       itemCount: squareItems.length,
  //       itemBuilder: (context, index) {
  //         return Padding(
  //           padding: const EdgeInsets.only(right: 12.0),
  //           child: GestureDetector(
  //             onTap: () {
  //               Navigator.pushNamed(
  //                 context,
  //                 squareItems[index].route,
  //               );
  //             },
  //             child: Container(
  //               width: 140,
  //               decoration: BoxDecoration(
  //                 borderRadius: BorderRadius.circular(8),
  //                 border: Border.all(
  //                   color: Colors.grey[300]!,
  //                   width: 1,
  //                 ),
  //               ),
  //               child: Column(
  //                 children: [
  //                   Expanded(
  //                     child: ClipRRect(
  //                       borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
  //                       child: Image.asset(
  //                         squareItems[index].imageUrl,
  //                         width: double.infinity,
  //                         fit: BoxFit.cover,
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }

  Widget _buildCategorySection(BuildContext context, String category, List<Product> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryDetailScreen(
                        category: category,
                        products: products,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'もっと見る',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (products.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                '商品がありません',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductDetailScreen(),
                        settings: RouteSettings(
                          arguments: products[index],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 8),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              child: Image.network(
                                products[index].imageUrls.isNotEmpty
                                    ? products[index].imageUrls[0]
                                    : '',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.error_outline,
                                        size: 24, color: Colors.red),
                                  );
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  products[index].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.mPlusRounded1c(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '¥${products[index].price.toStringAsFixed(0)}(税込)',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
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
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // endDrawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('SHOP'),
        centerTitle: true,
        // backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,

      ),
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
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
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
                                  borderSide: const BorderSide(color: Colors.black, width: 2.0),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              ),
                            ),
                          ),
                          // Builder(
                          //   builder: (BuildContext context) {
                          //     return IconButton(
                          //       icon: const Icon(Icons.menu),
                          //       color: Colors.black,
                          //       onPressed: () {
                          //         Scaffold.of(context).openEndDrawer();
                          //       },
                          //     );
                          //   },
                          // ),
                        ],
                      ),
                    ),
                    // _buildCategoryCircles(),
                    // _buildSquareItems(),
                    // const SizedBox(height: 5.0),
                    // _buildSquare2Items(),
                    // const SizedBox(height: 16.0),
                    // FutureBuilder<List<ShopEvent>>(
                    //   future: fetchShopEvents(),
                    //   builder: (context, snapshot) {
                    //     if (snapshot.hasError) {
                    //       print('Error in events: ${snapshot.error}');
                    //       return _buildCarousel([]);
                    //     }

                    //     if (snapshot.connectionState == ConnectionState.waiting) {
                    //       return _buildCarousel([]);
                    //     }

                    //     final now = DateTime.now();
                    //     final activeEvents = snapshot.data
                    //         ?.where((event) =>
                    //     event.isActive &&
                    //         now.isAfter(event.startDate) &&
                    //         now.isBefore(event.endDate))
                    //         .toList() ??
                    //         [];

                    //     return _buildCarousel(activeEvents);
                    //   },
                    // ),
                    const SizedBox(height: 20.0),
                    FutureBuilder<Map<String, List<Product>>>(
                      future: fetchProductsByCategory(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Text('データの読み込みに失敗しました: ${snapshot.error}'),
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text('商品が見つかりませんでした'),
                            ),
                          );
                        }

                        return Column(
                          children: snapshot.data!.entries.map((entry) {
                            return Column(
                              children: [
                                _buildCategorySection(context, entry.key, entry.value),
                                const SizedBox(height: 16),
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
      // bottomSheet: Container(
      //   decoration: BoxDecoration(
      //     color: Colors.white,
      //     boxShadow: [
      //       BoxShadow(
      //         color: Colors.grey.withValues(alpha: 0.2),
      //         spreadRadius: 0,
      //         blurRadius: 10,
      //         offset: const Offset(0, -2),
      //       ),
      //     ],
      //   ),
      //   child: SafeArea(
      //     top: false,
      //     child: Padding(
      //       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      //       child: Row(
      //         children: [
      //           Expanded(
      //             child: Material(
      //               color: Colors.white,
      //               child: InkWell(
      //                 onTap: () {
      //                   print('Favorite button tapped');
      //                 },
      //                 borderRadius: BorderRadius.circular(8),
      //                 child: Container(
      //                   padding: const EdgeInsets.symmetric(vertical: 12),
      //                   decoration: BoxDecoration(
      //                     border: Border.all(
      //                       color: Colors.black,
      //                       width: 1.0,
      //                     ),
      //                     borderRadius: BorderRadius.circular(8),
      //                   ),
      //                   child: const Row(
      //                     mainAxisAlignment: MainAxisAlignment.center,
      //                     children: [
      //                       Icon(
      //                         Icons.favorite_border,
      //                         color: Colors.black,
      //                         size: 24,
      //                       ),
      //                       SizedBox(width: 8),
      //                       Text(
      //                         'お気に入り',
      //                         style: TextStyle(
      //                           color: Colors.black,
      //                           fontWeight: FontWeight.w500,
      //                         ),
      //                       ),
      //                     ],
      //                   ),
      //                 ),
      //               ),
      //             ),
      //           ),
      //           const SizedBox(width: 12),
      //           Expanded(
      //             child: Material(
      //               color: Colors.white,
      //               child: InkWell(
      //                 onTap: () {
      //                   Navigator.push(
      //                     context,
      //                     MaterialPageRoute(builder: (context) => const CartScreen()),
      //                   );
      //                 },
      //                 borderRadius: BorderRadius.circular(8),
      //                 child: Container(
      //                   padding: const EdgeInsets.symmetric(vertical: 12),
      //                   decoration: BoxDecoration(
      //                     border: Border.all(
      //                       color: Colors.black,
      //                       width: 1.0,
      //                     ),
      //                     borderRadius: BorderRadius.circular(8),
      //                   ),
      //                   child: const Row(
      //                     mainAxisAlignment: MainAxisAlignment.center,
      //                     children: [
      //                       Icon(
      //                         Icons.shopping_cart_outlined,
      //                         color: Colors.black,
      //                         size: 24,
      //                       ),
      //                       SizedBox(width: 8),
      //                       Text(
      //                         'カート',
      //                         style: TextStyle(
      //                           color: Colors.black,
      //                           fontWeight: FontWeight.w500,
      //                         ),
      //                       ),
      //                     ],
      //                   ),
      //                 ),
      //               ),
      //             ),
      //           ),
      //         ],
      //       ),
      //     ),
      //   ),
      // ),
    );
  }
}

// Category Detail Screen
class CategoryDetailScreen extends StatelessWidget {
  final String category;
  final List<Product> products;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: products.isEmpty
          ? const Center(
        child: Text(
          '商品がありません',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.95,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) => ProductCard(
          product: products[index],
          onTap: () {
            Navigator.pushNamed(
              context,
              '/product_detail',
              arguments: products[index],
            );
          },
        ),
      ),
    );
  }
}