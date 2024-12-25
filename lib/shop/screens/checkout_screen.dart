import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/shop/screens/order_completion_screen..dart';
import 'package:parts/shop/screens/profile_screen.dart';

import '../models/cart_item.dart';
import '../services/cart_service.dart';
import '../services/coin_service.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final int totalAmount;

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isProcessing = false;
  String? _selectedAddressId;

  User? get currentUser => _auth.currentUser;

  int get _shippingFee => 1500;

  int get _totalWithShipping => widget.totalAmount + _shippingFee;

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
                  const SizedBox(height: 16),
                  _buildAfterCoins(),
                  const SizedBox(height: 16),
                  _buildAddressSelection(),
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
              children: [
                const Expanded(
                  child: Text(
                    '商品合計',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                Text(
                  '${widget.totalAmount} P',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '送料',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                Text(
                  '$_shippingFee P',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '合計（商品＋送料）',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_totalWithShipping P',
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
        final isEnoughBalance = balance >= _totalWithShipping;

        return SizedBox(
          width: double.infinity,
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '現在のコイン残高',
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
                      color: isEnoughBalance
                          ? const Color(0xFF00008B)
                          : Colors.red,
                    ),
                  ),
                  if (!isEnoughBalance) ...[
                    const SizedBox(height: 8),
                    Text(
                      '残高が不足しています（${(_totalWithShipping - balance)} P不足）',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAfterCoins() {
    return StreamBuilder<int>(
      stream: _coinService.getCoinBalance(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0;
        final isEnoughBalance = balance >= _totalWithShipping;
        final afterCoin = balance - _totalWithShipping;

        return SizedBox(
          width: double.infinity,
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '購入後のコイン残高',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$afterCoin P',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isEnoughBalance
                          ? const Color(0xFF00008B)
                          : Colors.red,
                    ),
                  ),
                  if (!isEnoughBalance) ...[
                    const SizedBox(height: 8),
                    Text(
                      '残高が不足しています（${(_totalWithShipping - balance)} P不足）',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddressSelection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(currentUser?.uid)
          .collection('user_addresses')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('エラーが発生しました');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final addresses = snapshot.data?.docs ?? [];

        if (addresses.isEmpty) {
          return SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'お届け先住所',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        '登録済みの住所がありません',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddressFormScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00008B),
                        ),
                        child: const Text(
                          '新しい住所を登録する',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'お届け先住所',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...addresses.map<Widget>((doc) {
                  final address = doc.data() as Map<String, dynamic>;
                  final addressId = doc.id;
                  final fullAddress =
                      '${address['prefecture']} ${address['city']} ${address['street']} ${address['building']}';
                  return RadioListTile<String>(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${address['label']} - ${address['name']}'),
                        Text(fullAddress, style: const TextStyle(fontSize: 14)),
                        Text('〒${address['postalCode']}',
                            style: const TextStyle(fontSize: 14)),
                        Text(address['phoneNumber'],
                            style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                    value: addressId,
                    groupValue: _selectedAddressId,
                    onChanged: (value) {
                      setState(() => _selectedAddressId = value);
                    },
                  );
                }).toList(),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddressFormScreen(),
                      ),
                    );
                  },
                  child: const Text('新しい住所を追加'),
                ),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('users')
              .doc(currentUser?.uid)
              .collection('user_addresses')
              .snapshots(),
          builder: (context, addressSnapshot) {
            return StreamBuilder<int>(
              stream: _coinService.getCoinBalance(),
              builder: (context, coinSnapshot) {
                final balance = coinSnapshot.data ?? 0;
                final isEnoughBalance = balance >= _totalWithShipping;

                final hasAddress = (addressSnapshot.data?.docs.length ?? 0) > 0;

                String buttonText = '注文を確定する';
                bool isEnabled = !_isProcessing &&
                    isEnoughBalance &&
                    _selectedAddressId != null &&
                    hasAddress;

                if (!hasAddress) {
                  buttonText = '住所を登録してください';
                  isEnabled = false;
                } else if (!isEnoughBalance) {
                  buttonText = 'コインをチャージしてください';
                } else if (_selectedAddressId == null) {
                  buttonText = 'お届け先住所を選択してください';
                }

                return ElevatedButton(
                  onPressed: isEnabled ? () => _processCheckout(context) : null,
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
                          buttonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _processCheckout(BuildContext context) async {
    setState(() => _isProcessing = true);

    try {
      await _coinService.useCoins(_totalWithShipping);

      final user = currentUser;
      if (user == null) {
        throw 'ユーザーがログインしていません';
      }

      // Get selected address
      final addressDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('user_addresses')
          .doc(_selectedAddressId)
          .get();

      if (!addressDoc.exists) {
        throw '配送先住所が選択されていません';
      }

      final selectedAddress = addressDoc.data()!;

      final orderRef = _firestore.collection('shopping_list').doc();
      await orderRef.set({
        'orderId': orderRef.id,
        'totalAmount': _totalWithShipping,
        'orderItems': widget.cartItems
            .map((item) => {
                  'productName': item.productName,
                  'quantity': item.quantity,
                  'totalPrice': item.totalPrice,
                })
            .toList(),
        'shippingFee': _shippingFee,
        'userId': user.uid,
        'userName': user.displayName ?? '匿名',
        'userEmail': user.email ?? '未設定',
        'deliveryAddress': selectedAddress,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _cartService.clearCart();

      // ignore: use_build_context_synchronously
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => OrderCompletionScreen(
            orderItems: widget.cartItems,
            totalAmount: _totalWithShipping.toDouble(),
            orderId: orderRef.id,
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
