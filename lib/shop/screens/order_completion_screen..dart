import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import 'product_list_screen.dart';

class OrderCompletionScreen extends StatelessWidget {
  final List<CartItem> orderItems;
  final double totalAmount;
  final String orderId; // 注文IDを追加

  const OrderCompletionScreen({
    Key? key,
    required this.orderItems,
    required this.totalAmount,
    required this.orderId, // コンストラクタで受け取る
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF00008B),
                size: 120,
              ),
              const SizedBox(height: 24),
              const Text(
                'ご注文ありがとうございます',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                '注文が完了しました\n合計金額: ${totalAmount.toStringAsFixed(0)} P',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              // 注文番号を表示
              Text('注文番号：$orderId\nお問い合わせの際にこちらをお伝えください。'),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductListScreen(),
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00008B),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ショップに戻る',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
