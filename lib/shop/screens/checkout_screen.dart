import 'package:flutter/material.dart';
import 'package:parts/shop/screens/order_completion_screen..dart';

import '../models/cart_item.dart';
import '../services/cart_service.dart';
import '../services/coin_service.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final double totalAmount;

  const CheckoutScreen({
    Key? key,
    required this.cartItems,
    required this.totalAmount,
  }) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final CoinService _coinService = CoinService();
  final CartService _cartService = CartService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '注文確認',
          style: TextStyle(
            color: Color(0xFF00008B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderSummary(),
                  const SizedBox(height: 24),
                  _buildCoinBalance(),
                ],
              ),
            ),
          ),
          _buildCheckoutButton(),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '注文内容',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.cartItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      Text(
                        '${item.quantity}個',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${item.totalPrice.toStringAsFixed(0)} P',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '合計',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.totalAmount.toStringAsFixed(0)} P',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00008B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinBalance() {
    return StreamBuilder<int>(
      stream: _coinService.getCoinBalance(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0;
        final isEnoughBalance = balance >= widget.totalAmount;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'コイン残高',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$balance P',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color:
                        isEnoughBalance ? const Color(0xFF00008B) : Colors.red,
                  ),
                ),
                if (!isEnoughBalance) ...[
                  const SizedBox(height: 8),
                  Text(
                    '残高が不足しています（${(widget.totalAmount - balance).toStringAsFixed(0)} P不足）',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: StreamBuilder<int>(
          stream: _coinService.getCoinBalance(),
          builder: (context, snapshot) {
            final balance = snapshot.data ?? 0;
            final isEnoughBalance = balance >= widget.totalAmount;

            return ElevatedButton(
              onPressed: _isProcessing || !isEnoughBalance
                  ? null
                  : () => _processCheckout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00008B),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Text(
                      isEnoughBalance ? '注文を確定する' : 'コインをチャージしてください',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _processCheckout(BuildContext context) async {
    setState(() => _isProcessing = true);

    try {
      // コインを使用
      await _coinService.useCoins(widget.totalAmount.toInt());

      // カートをクリア
      await _cartService.clearCart();

      // 注文完了画面に遷移
      // ignore: use_build_context_synchronously
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => OrderCompletionScreen(
            orderItems: widget.cartItems,
            totalAmount: widget.totalAmount,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }
}
