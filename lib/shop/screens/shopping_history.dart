import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/shop/screens/report_shopping.dart';

class ShoppingHistoryScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ShoppingHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ショッピング履歴',
          style: TextStyle(
            color: Color(0xFF00008B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('shopping_list').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('エラーが発生しました'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('履歴がありません'));
          }

          final user = _auth.currentUser;
          if (user == null) {
            return const Center(child: Text('ログインしてください'));
          }

          final orders = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (!data.containsKey('userId')) {
              return false;
            }
            return data['userId'] == user.uid;
          }).toList();

          if (orders.isEmpty) {
            return const Center(child: Text('履歴がありません'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;
              final orderItems =
                  List<Map<String, dynamic>>.from(data['orderItems'] ?? []);
              final totalAmount = data['totalAmount'];
              final orderId = data['orderId'];
              final timestamp = data['timestamp'];

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '注文番号: $orderId',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '合計金額: ${totalAmount} P',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ...orderItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item['productName'] ?? '不明な商品',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Text(
                                '${item['quantity']}個',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${item['totalPrice']} P',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text(
                          '注文日時: ${timestamp?.toDate()?.toLocal() ?? '不明'}',
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InquiryFormPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.more_vert,
                                color: Color(0xFF00008B)),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
