import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parts/setting_page/address/add_address_screen.dart';
import 'package:parts/shop/check_out.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _deliveryMethod = '通常配送';
  String _deliveryDate = '指定なし(最短発送)';
  String _deliveryTime = '時間指定なし';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<CartItem> cartItems = [];
  bool isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      // ユーザーがログインしていない場合はログイン画面にリダイレクト
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    await _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    if (_currentUser == null) return;

    try {
      final cartSnapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('shopping_cart')
          .get();

      List<CartItem> items = [];
      for (var doc in cartSnapshot.docs) {
        final productSnapshot = await _firestore
            .collection('products')
            .doc(doc.data()['productId'])
            .get();

        if (productSnapshot.exists) {
          final productData = productSnapshot.data()!;
          final imageUrls = productData['imageUrls'] as List<dynamic>?;
          final imageUrl = imageUrls != null && imageUrls.isNotEmpty
              ? imageUrls[0] as String
              : '';

          items.add(CartItem(
            id: doc.id,
            productId: doc.data()['productId'],
            brand: '', // 必要に応じて追加
            name: productData['name'],
            variant: '', // 必要に応じて追加
            price: productData['price'],
            imageUrl: imageUrl,
            quantity: doc.data()['quantity'],
          ));
        }
      }

      setState(() {
        cartItems = items;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading cart items: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateQuantity(CartItem item, int newQuantity) async {
    if (_currentUser == null) return;
    if (newQuantity < 1) return;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('shopping_cart')
          .doc(item.id)
          .update({'quantity': newQuantity});

      setState(() {
        item.quantity = newQuantity;
      });
    } catch (e) {
      print('Error updating quantity: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('数量の更新に失敗しました。もう一度お試しください。'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeItem(CartItem item) async {
    if (_currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('shopping_cart')
          .doc(item.id)
          .delete();

      setState(() {
        cartItems.remove(item);
      });
    } catch (e) {
      print('Error removing item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('商品の削除に失敗しました。もう一度お試しください。'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _proceedToCheckout() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ログインが必要です'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    try {
      final userAddressSnapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('user_addresses')
          .get();

      final totalAmount = _calculateTotal();

      if (userAddressSnapshot.docs.isEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AddAddressScreen(),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CheckoutScreen(
              totalAmount: totalAmount,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('エラーが発生しました。もう一度お試しください。'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error checking user addresses: $e');
    }
  }

  int _calculateTotal() {
    return cartItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'カートには商品が入っていません',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'ログインが必要です',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00008b),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('ログインする'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'カート',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.white,
        ),
        body: _buildLoginRequired(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'カート',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : cartItems.isEmpty
          ? _buildEmptyCart()
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'カートに入っている商品：${cartItems.length} 点',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...cartItems.map((item) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.brand,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.variant,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '¥${item.price.toString()}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () {
                                      if (item.quantity > 1) {
                                        _updateQuantity(item, item.quantity - 1);
                                      }
                                    },
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  Text(
                                    item.quantity.toString(),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      _updateQuantity(item, item.quantity + 1);
                                    },
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _removeItem(item),
                              child: const Text(
                                '削除',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )).toList(),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '小計',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          '¥${_calculateTotal().toString()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '配送方法',
                              style: TextStyle(fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.help_outline),
                              onPressed: () {
                                // ヘルプ表示
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _deliveryMethod,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '配送日時指定',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '「指定なし」で最短でのお届けとなります',
                          style: TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _deliveryDate,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              items: ['指定なし(最短発送)'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _deliveryDate = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _deliveryTime,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              items: ['時間指定なし'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _deliveryTime = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                // 配送日指定についての説明
                              },
                              child: Row(
                                children: const [
                                  Text(
                                    '配送日指定について',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                  Icon(
                                    Icons.open_in_new,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: cartItems.isEmpty ? null : _proceedToCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00008b),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '購入手続きへ進む',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.question_mark),
                      onPressed: () {
                        // チャット機能
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CartItem {
  final String id;
  final String productId;
  final String brand;
  final String name;
  final String variant;
  final int price;
  final String imageUrl;
  int quantity;

  CartItem({
    required this.id,
    required this.productId,
    required this.brand,
    required this.name,
    required this.variant,
    required this.price,
    required this.imageUrl,
    required this.quantity,
  });
}