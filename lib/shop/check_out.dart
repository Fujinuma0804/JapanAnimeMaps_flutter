import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parts/setting_page/address/add_address_screen.dart';
import 'package:parts/shop/order_complete.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:parts/shop/payment_loading_screen.dart';

// 住所詳細画面
class AddressDetailScreen extends StatelessWidget {
  final UserAddress address;

  const AddressDetailScreen({Key? key, required this.address}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '住所詳細',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailItem(
                    icon: Icons.person,
                    label: 'お名前',
                    value: address.fullName,
                    subValue: address.fullNameKana,
                  ),
                  const SizedBox(height: 20),
                  _buildDetailItem(
                    icon: Icons.phone,
                    label: '電話番号',
                    value: address.phoneNumber,
                  ),
                  const SizedBox(height: 20),
                  _buildDetailItem(
                    icon: Icons.location_on,
                    label: '郵便番号',
                    value: '〒${address.postalCode}',
                  ),
                  const SizedBox(height: 20),
                  _buildDetailItem(
                    icon: Icons.map,
                    label: '都道府県',
                    value: address.prefecture,
                  ),
                  const SizedBox(height: 20),
                  _buildDetailItem(
                    icon: Icons.location_city,
                    label: '市区町村',
                    value: address.city,
                  ),
                  const SizedBox(height: 20),
                  _buildDetailItem(
                    icon: Icons.home,
                    label: '番地',
                    value: address.streetAddress,
                  ),
                  if (address.building.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildDetailItem(
                      icon: Icons.business,
                      label: '建物名',
                      value: address.building,
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildDetailItem(
                    icon: Icons.calendar_today,
                    label: '登録日時',
                    value: _formatDateTime(address.createdAt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00008b).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF00008b),
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subValue != null) ...[
                const SizedBox(height: 2),
                Text(
                  subValue,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
class CheckoutScreen extends StatefulWidget {
  final int totalAmount;
  const CheckoutScreen({
    Key? key,
    required this.totalAmount,
  }) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with SingleTickerProviderStateMixin {
  static const String API_KEY = "497b8d79cde427967b4ed7d74b07dbc9b6a173c010b4836ea37505b3d8fbeddf";
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool isLoading = true;
  List<UserAddress> addresses = [];
  String? selectedAddressId;
  int? shippingCost;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  CardFieldInputDetails? _card;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    await _loadAddresses();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    if (_currentUser == null) return;

    try {
      final addressSnapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('user_addresses')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        addresses = addressSnapshot.docs
            .map((doc) => UserAddress.fromFirestore(doc))
            .toList();
        if (addresses.isNotEmpty) {
          selectedAddressId = addresses[0].id;
          _updateShippingCost(addresses[0].prefecture);
        }
        isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      print('Error loading addresses: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateShippingCost(String prefecture) async {
    try {
      final rateDoc = await _firestore
          .collection('postage')
          .doc('rates')
          .get();

      if (rateDoc.exists) {
        final rates = rateDoc.data() as Map<String, dynamic>;
        setState(() {
          shippingCost = rates[prefecture] as int;
        });
      }
    } catch (e) {
      print('Error loading shipping cost: $e');
    }
  }

  Widget _buildStripeCardField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'カード情報を入力',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: CardField(
              onCardChanged: (card) {
                setState(() {
                  _card = card;
                });
              },
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey.shade400),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildOrderSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今回のご請求額',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('小計'),
              Text(
                '¥${widget.totalAmount.toString()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('送料'),
              Text(
                shippingCost != null ? '¥${shippingCost.toString()}' : '住所を選択してください',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '合計',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                shippingCost != null
                    ? '¥${(widget.totalAmount + shippingCost!).toString()}'
                    : '¥${widget.totalAmount.toString()}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF00008b),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleStripePayment() async {
    if (_currentUser == null || selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ログインまたは配送先住所の選択が必要です'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 16.0,
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: const Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: PaymentLoadingScreen(),
          ),
        );
      },
    );

    try {
      final baseUrl = Platform.isAndroid
          ? 'http://10.0.2.2:3000'
          : 'http://localhost:3000';

      try {
        final healthCheck = await http.get(
            Uri.parse('$baseUrl/health'),
          headers: {
            'x-api-key': API_KEY,  // APIキーを追加
          },
        );
        print('サーバーステータス: ${healthCheck.body}');
      } catch (e) {
        print('サーバーヘルスチェックエラー: $e');
        throw Exception('サーバーに接続できません');
      }

      final totalAmount = shippingCost != null
          ? widget.totalAmount + shippingCost!
          : widget.totalAmount;

      final response = await http.post(
        Uri.parse('$baseUrl/create-payment-intent'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-api-key': API_KEY,  // APIキーを追加
        },
        body: json.encode({
          'amount': totalAmount,
          'currency': 'jpy'
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Payment intent creation failed: ${response.body}');
      }

      final paymentIntentData = json.decode(response.body);
      final clientSecret = paymentIntentData['clientSecret'];

      if (clientSecret == null) {
        throw Exception('Client secret is missing in the response');
      }

      final paymentResult = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      final cartSnapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('shopping_cart')
          .get();

      List<Map<String, dynamic>> orderItems = [];
      for (var doc in cartSnapshot.docs) {
        final data = doc.data();
        if (data != null) {
          orderItems.add({
            'productId': data['productId'] ?? '',
            'productName': data['name'] ?? '',
            'quantity': data['quantity'] ?? 1,
            'totalPrice': (data['price'] ?? 0) * (data['quantity'] ?? 1),
          });
        }
      }

      final addressSnapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('user_addresses')
          .doc(selectedAddressId)
          .get();

      final addressData = addressSnapshot.data() ?? {};

      final userSnapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      final userData = userSnapshot.data() ?? {};

      final orderId = DateTime.now().millisecondsSinceEpoch.toString();
      await _firestore.collection('shopping_list').doc(orderId).set({
        'orderId': orderId,
        'orderItems': orderItems,
        'deliveryAddress': {
          'building': addressData['building'] ?? '',
          'city': addressData['city'] ?? '',
          'label': addressData['label'] ?? '自宅',
          'name': '${addressData['lastName'] ?? ''} ${addressData['firstName'] ?? ''}',
          'phoneNumber': addressData['phoneNumber'] ?? '',
          'postalCode': addressData['postalCode'] ?? '',
          'prefecture': addressData['prefecture'] ?? '',
          'street': addressData['streetAddress'] ?? '',
        },
        'shippingFee': shippingCost ?? 0,
        'timestamp': FieldValue.serverTimestamp(),
        'totalAmount': totalAmount,
        'userEmail': userData['email'] ?? '',
        'userId': _currentUser!.uid,
        'userName': userData['displayName'] ?? '匿名',
      });

      for (var doc in cartSnapshot.docs) {
        await doc.reference.delete();
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const OrderCompleteScreen(),
        ),
            (route) => false,
      );

    } catch (e, stackTrace) {
      print('エラーの詳細: $e');
      print('スタックトレース: $stackTrace');
      Navigator.of(context).pop();

      String errorMessage = '決済処理中にエラーが発生しました';
      if (e is StripeException) {
        errorMessage = e.error.localizedMessage ?? errorMessage;
      } else {
        errorMessage = '$errorMessage: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 16.0,
          ),
        ),
      );
    }
  }

  Future<void> _processOrder() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ログインしてください'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF323232),
        ),
      );
      return;
    }

    if (selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配送先住所を選択してください'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF323232),
        ),
      );
      return;
    }

    try {
      final totalAmount = shippingCost != null
          ? widget.totalAmount + shippingCost!
          : widget.totalAmount;

      await _firestore.collection('orders').add({
        'userId': _currentUser!.uid,
        'addressId': selectedAddressId,
        'paymentMethod': 'credit_card',
        'status': 'pending',
        'amount': totalAmount,
        'shippingCost': shippingCost,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('shopping_cart')
          .get()
          .then((snapshot) {
        for (DocumentSnapshot doc in snapshot.docs) {
          doc.reference.delete();
        }
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const OrderCompleteScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('注文処理中にエラーが発生しました。もう一度お試しください。'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF00008b),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildAddressCard(UserAddress address) {
    final isSelected = selectedAddressId == address.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2FD) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF00008b) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            RadioListTile<String>(
              title: Text(
                address.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '〒${address.postalCode}\n${address.prefecture}${address.city}${address.streetAddress}${address.building.isNotEmpty ? '\n${address.building}' : ''}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              value: address.id,
              groupValue: selectedAddressId,
              onChanged: (value) {
                setState(() {
                  selectedAddressId = value;
                  _updateShippingCost(address.prefecture);
                });
              },
              activeColor: const Color(0xFF00008b),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddressDetailScreen(
                            address: address,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.info_outline,
                      size: 18,
                    ),
                    label: const Text('詳細'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00008b),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
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

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('ログインが必要です'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'お届け先・支払い方法の選択',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('お届け先住所'),
                    ...addresses.map(_buildAddressCard),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const AddAddressScreen(),
                            ),
                          ).then((_) => _loadAddresses());
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('新しい住所を追加'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00008b),
                        ),
                      ),
                    ),
                    const Divider(height: 32),
                    _buildOrderSummary(),
                    const Divider(height: 32),
                    _buildSectionTitle('クレジットカード情報'),
                    _buildStripeCardField(),
                    const SizedBox(height: 24),
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
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleStripePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00008b),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    '注文を確定する',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserAddress {
  final String id;
  final String postalCode;
  final String prefecture;
  final String city;
  final String streetAddress;
  final String building;
  final String firstName;
  final String firstNameKana;
  final String lastName;
  final String lastNameKana;
  final String phoneNumber;
  final DateTime createdAt;

  UserAddress({
    required this.id,
    required this.postalCode,
    required this.prefecture,
    required this.city,
    required this.streetAddress,
    required this.building,
    required this.firstName,
    required this.firstNameKana,
    required this.lastName,
    required this.lastNameKana,
    required this.phoneNumber,
    required this.createdAt,
  });

  String get fullName => '$lastName $firstName';
  String get fullNameKana => '$lastNameKana $firstNameKana';

  factory UserAddress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserAddress(
      id: doc.id,
      postalCode: data['postalCode'] ?? '',
      prefecture: data['prefecture'] ?? '',
      city: data['city'] ?? '',
      streetAddress: data['streetAddress'] ?? '',
      building: data['building'] ?? '',
      firstName: data['firstName'] ?? '',
      firstNameKana: data['firstNameKana'] ?? '',
      lastName: data['lastName'] ?? '',
      lastNameKana: data['lastNameKana'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}