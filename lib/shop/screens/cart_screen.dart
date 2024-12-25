import 'package:flutter/material.dart';
import 'package:parts/shop/models/cart_item.dart';
import 'package:parts/shop/screens/checkout_screen.dart';
import 'package:parts/shop/services/cart_service.dart';

class CartScreen extends StatelessWidget {
  final CartService _cartService = CartService();

  CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'カート',
          style: TextStyle(
            color: Color(0xFF00008B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('カートを空にする'),
                  content: const Text('カート内のすべての商品を削除しますか？'),
                  actions: [
                    TextButton(
                      child: const Text('キャンセル'),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    TextButton(
                      child: const Text('削除'),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await _cartService.clearCart();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('カートを空にしました')),
                );
              }
            },
            child: const Text(
              'カートを空にする',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<CartItem>>(
        stream: _cartService.getCartItems(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cartItems = snapshot.data!;

          if (cartItems.isEmpty) {
            return const Center(
              child: Text(
                'カートは空です',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return _CartItemTile(
                      item: item,
                      onUpdateQuantity: (quantity) {
                        _cartService.updateQuantity(item.id, quantity);
                      },
                      onRemove: () {
                        _cartService.removeFromCart(item.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('商品を削除しました')),
                        );
                      },
                    );
                  },
                ),
              ),
              _CartSummary(cartItems: cartItems),
            ],
          );
        },
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final Function(int) onUpdateQuantity;
  final VoidCallback onRemove;

  const _CartItemTile({
    Key? key,
    required this.item,
    required this.onUpdateQuantity,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.error),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.price.toStringAsFixed(0)} P',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF00008B),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () => onUpdateQuantity(item.quantity - 1),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => onUpdateQuantity(item.quantity + 1),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onRemove,
                  child: const Text(
                    '削除',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final List<CartItem> cartItems;

  const _CartSummary({
    Key? key,
    required this.cartItems,
  }) : super(key: key);

  double get totalAmount {
    return cartItems.fold(0, (sum, item) => sum + item.totalPrice);
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                  '${totalAmount.toStringAsFixed(0)} P',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00008B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: cartItems.isEmpty
                  ? null
                  : () {
                      // TODO: チェックアウト処理の実装
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CheckoutScreen(
                            cartItems: cartItems,
                            totalAmount: totalAmount,
                          ),
                        ),
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
                'レジに進む',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
