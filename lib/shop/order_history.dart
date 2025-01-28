import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:parts/shop/order_history_detail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum OrderStatus {
  received,
  processing,
  preparing,
  shipped,
  cancelled,
}

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  _OrderHistoryScreenState createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late Stream<List<ShoppingOrder>> _ordersStream;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _ordersStream = _getOrdersStream();
    _debugCurrentUser();
  }

  Future<void> _debugCurrentUser() async {
    final user = _auth.currentUser;
    print('Debug - Current User:');
    print('User ID: ${user?.uid}');
    print('User Email: ${user?.email}');
    print('User is Anonymous: ${user?.isAnonymous}');

    if (user != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        print('User document exists: ${userDoc.exists}');
        if (userDoc.exists) {
          print('User document data: ${userDoc.data()}');
        }
      } catch (e) {
        print('Error checking user document: $e');
      }
    }
  }

  Stream<List<ShoppingOrder>> _getOrdersStream() {
    final userId = _auth.currentUser?.uid;
    print('Debug - Getting orders stream for user ID: $userId');

    if (userId == null) {
      print('Debug - No user ID found');
      return Stream.value([]);
    }

    return _firestore.collection('shopping_list').snapshots().asyncMap((snapshot) async {
      print('Debug - Received snapshot with ${snapshot.docs.length} documents');
      return await _processSnapshot(snapshot);
    }).handleError((error) {
      print('Debug - Stream error: $error');
      _lastError = error.toString();
      throw error;
    });
  }

  Future<Map<String, ProductInfo>> _fetchProductsInfo(List<String> productIds) async {
    final productsMap = <String, ProductInfo>{};

    for (final productId in productIds) {
      try {
        final doc = await _firestore.collection('products').doc(productId).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          productsMap[productId] = ProductInfo(
            name: data['name'] as String? ?? '不明な商品',
            price: (data['price'] as num?)?.toDouble() ?? 0.0,
            imageUrl: data['imageUrl'] as String? ?? '',
          );
        }
      } catch (e) {
        print('Debug - Error fetching product $productId: $e');
      }
    }

    return productsMap;
  }

  Future<List<ShoppingOrder>> _processSnapshot(QuerySnapshot snapshot) async {  // Order を ShoppingOrder に変更
    try {
      final orders = <ShoppingOrder>[];  // Order を ShoppingOrder に変更

      for (final doc in snapshot.docs) {
        print('Debug - Processing document ID: ${doc.id}');
        final data = doc.data() as Map<String, dynamic>;
        print('Debug - Document data: $data');

        if (data['userId'] != _auth.currentUser?.uid) {
          continue;
        }

        if (!data.containsKey('orderItems')) {
          print('Debug - Missing orderItems field in document ${doc.id}');
          continue;
        }

        final rawItems = data['orderItems'] as List<dynamic>;
        final productIds = rawItems
            .map((item) => item['productId'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toList();

        final productsInfo = await _fetchProductsInfo(productIds);
        final items = _processOrderItems(rawItems, productsInfo);
        final status = _processOrderStatus(data['status']);
        final timestamp = _processTimestamp(data['timestamp']);

        orders.add(ShoppingOrder(  // Order を ShoppingOrder に変更
          id: data['orderId'] as String? ?? doc.id,
          date: timestamp,
          items: items,
          status: status,
        ));
      }

      return orders;
    } catch (e, stackTrace) {
      print('Debug - Error processing snapshot: $e');
      print('Debug - Stack trace: $stackTrace');
      rethrow;
    }
  }


  List<OrderItem> _processOrderItems(
      List<dynamic> items,
      Map<String, ProductInfo> productsInfo,
      ) {
    return items.map((item) {
      try {
        final productId = item['productId'] as String?;
        final productInfo = productId != null ? productsInfo[productId] : null;

        return OrderItem(
          productId: productId ?? '',
          name: productInfo?.name ?? item['productName'] as String? ?? '不明な商品',
          price: productInfo?.price ?? (item['totalPrice'] as num?)?.toDouble() ?? 0.0,
          quantity: item['quantity'] as int? ?? 1,
          imageUrl: productInfo?.imageUrl ?? '',
        );
      } catch (e) {
        print('Debug - Error processing order item: $e');
        print('Debug - Item data: $item');
        rethrow;
      }
    }).toList();
  }

  OrderStatus _processOrderStatus(dynamic statusData) {
    final statusStr = statusData?.toString().toLowerCase() ?? 'received';
    print('Debug - Processing status: $statusStr');

    switch (statusStr) {
      case 'processing':
        return OrderStatus.processing;
      case 'preparing':
        return OrderStatus.preparing;
      case 'shipped':
        return OrderStatus.shipped;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.received;
    }
  }

  DateTime _processTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    print('Debug - Invalid timestamp format: $timestamp');
    return DateTime.now();
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'エラーが発生しました',
              style: GoogleFonts.notoSans(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.notoSans(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _lastError = null;
                  _ordersStream = _getOrdersStream();
                });
              },
              child: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          '注文履歴',
          style: GoogleFonts.notoSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<ShoppingOrder>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('Debug - StreamBuilder error: ${snapshot.error}');
            return _buildErrorWidget(snapshot.error.toString());
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return Center(
              child: Text(
                '注文履歴がありません',
                style: GoogleFonts.notoSans(
                  color: Colors.grey[600],
                ),
              ),
            );
          }

          orders.sort((a, b) => b.date.compareTo(a.date));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _OrderCard(order: order);
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final ShoppingOrder order;

  const _OrderCard({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalAmount = order.items.fold<double>(
      0,
          (sum, item) => sum + (item.price * item.quantity),
    );

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailScreen(order: order),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '注文番号: ${order.id}',
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('yyyy年MM月dd日').format(order.date),
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  _StatusBadge(status: order.status),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: order.items.length,
              itemBuilder: (context, index) {
                final item = order.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: item.imageUrl.isNotEmpty
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Icon(Icons.shopping_bag_outlined,
                            color: Colors.grey[400]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: GoogleFonts.notoSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${NumberFormat('#,###').format(item.price)}円 × ${item.quantity}',
                              style: GoogleFonts.notoSans(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '合計',
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '¥${NumberFormat('#,###').format(totalAmount)}',
                    style: GoogleFonts.notoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
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

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;

  const _StatusBadge({
    Key? key,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String text;

    switch (status) {
    case OrderStatus.received:
    backgroundColor = Colors.orange[50]!;
    textColor = Colors.orange[700]!;
    text = '受付';
    break;
      case OrderStatus.processing:
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        text = '処理中';
        break;
      case OrderStatus.preparing:
        backgroundColor = Colors.purple[50]!;
        textColor = Colors.purple[700]!;
        text = '発送準備';
        break;
      case OrderStatus.shipped:
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        text = '発送済み';
        break;
      case OrderStatus.cancelled:
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        text = 'キャンセル';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.notoSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

class ShoppingOrder {
  final String id;
  final DateTime date;
  final List<OrderItem> items;
  final OrderStatus status;

  ShoppingOrder({
    required this.id,
    required this.date,
    required this.items,
    required this.status,
  });
}

class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });
}

class ProductInfo {
  final String name;
  final double price;
  final String imageUrl;

  ProductInfo({
    required this.name,
    required this.price,
    required this.imageUrl,
  });
}