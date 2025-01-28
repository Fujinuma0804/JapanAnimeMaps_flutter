import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:parts/shop/order_history.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderDetailScreen extends StatefulWidget {
  final ShoppingOrder order;

  const OrderDetailScreen({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  DeliveryInfo? _deliveryInfo;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDeliveryInfo();
  }

  Future<void> _fetchDeliveryInfo() async {
    try {
      final doc = await _firestore
          .collection('shopping_list')
          .doc(widget.order.id)
          .get();

      if (!doc.exists) {
        setState(() {
          _error = 'お届け先情報が見つかりませんでした';
          _isLoading = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final deliveryData = data['deliveryAddress']
          as Map<String, dynamic>?; // deliveryInfo から deliveryAddress に変更

      if (deliveryData == null) {
        setState(() {
          _error = 'お届け先情報が含まれていません';
          _isLoading = false;
        });
        return;
      }

      // フィールド名を実際のデータ構造に合わせて変更
      setState(() {
        _deliveryInfo = DeliveryInfo(
          name: deliveryData['name'] as String? ?? '',
          postalCode: deliveryData['postalCode'] as String? ?? '',
          address: _buildFullAddress(
            prefecture: deliveryData['prefecture'] as String? ?? '',
            city: deliveryData['city'] as String? ?? '',
            street: deliveryData['street'] as String? ?? '',
            building: deliveryData['building'] as String? ?? '',
          ),
          phoneNumber: deliveryData['phoneNumber'] as String? ?? '',
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'お届け先情報の取得中にエラーが発生しました';
        _isLoading = false;
      });
      print('Error fetching delivery info: $e');
    }
  }

  String _buildFullAddress({
    required String prefecture,
    required String city,
    required String street,
    required String building,
  }) {
    final parts = <String>[prefecture, city, street, building];
    return parts.where((part) => part.isNotEmpty).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.order.items.fold<double>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          '注文詳細',
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 注文情報セクション
            _buildOrderInfoSection(),

            // 注文商品セクション
            _buildOrderItemsSection(totalAmount),

            // お届け先情報セクション
            _buildDeliveryInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderProgress(OrderStatus status, BuildContext context) {
    final List<Map<String, dynamic>> steps = [
      {'status': OrderStatus.received, 'label': '受付'},
      {'status': OrderStatus.processing, 'label': '処理中'},
      {'status': OrderStatus.preparing, 'label': '発送準備'},
      {'status': OrderStatus.shipped, 'label': '発送済み'},
    ];

    int currentStep;
    switch (status) {
      case OrderStatus.received:
        currentStep = 0;
        break;
      case OrderStatus.processing:
        currentStep = 1;
        break;
      case OrderStatus.preparing:
        currentStep = 2;
        break;
      case OrderStatus.shipped:
        currentStep = 3;
        break;
      case OrderStatus.cancelled:
        currentStep = -1;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  '注文状況',
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _getStatusText(status),
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (status != OrderStatus.cancelled)
          Padding(
            padding: const EdgeInsets.only(left: 100, right: 16),
            child: Column(
              children: [
                SizedBox(
                  height: 24,
                  child: Stack(
                    children: [
                      // ベースとなる線（グレー）
                      Positioned(
                        top: 11,
                        child: Container(
                          width: MediaQuery.of(context).size.width - 132,
                          height: 2,
                          color: Colors.grey[200],
                        ),
                      ),
                      // 進捗を示す線（緑）
                      if (currentStep >= 0)
                        Positioned(
                          top: 11,
                          child: Container(
                            width: (MediaQuery.of(context).size.width - 132) *
                                ((currentStep + 1) / steps.length),
                            height: 2,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                      // ステータスを示す丸印
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: steps.asMap().entries.map((entry) {
                          final index = entry.key;
                          final isCompleted = index <= currentStep;
                          return Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey[200],
                            ),
                            child: isCompleted
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // ステータスのラベル
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final isCompleted = index <= currentStep;
                    return Text(
                      entry.value['label'] as String,
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: isCompleted
                            ? const Color(0xFF4CAF50)
                            : Colors.grey[600],
                        fontWeight:
                            isCompleted ? FontWeight.w500 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          )
        else
          // キャンセル表示
          Row(
            children: [
              const SizedBox(width: 100),
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE53935),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'キャンセル',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  color: const Color(0xFFE53935),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildOrderInfoSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
          Text(
            '注文情報',
            style: GoogleFonts.notoSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('注文番号', widget.order.id),
          _buildInfoRow(
              '注文日', DateFormat('yyyy年MM月dd日').format(widget.order.date)),
          _buildOrderProgress(widget.order.status, context),
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
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
                : Icon(Icons.shopping_bag_outlined, color: Colors.grey[400]),
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
                  '${NumberFormat('#,###').format(item.price)}円',
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '数量: ${item.quantity}',
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${NumberFormat('#,###').format(item.price * item.quantity)}円',
            style: GoogleFonts.notoSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsSection(double totalAmount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
          Text(
            '注文商品',
            style: GoogleFonts.notoSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...widget.order.items.map((item) => _buildOrderItemRow(item)),
          const Divider(height: 32),
          _buildTotalRow('商品合計', totalAmount, context: context),
          _buildTotalRow('送料', 550, context: context),
          const SizedBox(height: 8),
          _buildTotalRow('総合計', totalAmount + 550,
              isGrandTotal: true, context: context),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
          Text(
            'お届け先情報',
            style: GoogleFonts.notoSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: Text(
                _error!,
                style: GoogleFonts.notoSans(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            )
          else if (_deliveryInfo != null) ...[
            _buildInfoRow('お名前', _deliveryInfo!.name),
            _buildInfoRow('郵便番号', _deliveryInfo!.postalCode),
            _buildInfoRow('住所', _deliveryInfo!.address),
            _buildInfoRow('電話番号', _deliveryInfo!.phoneNumber),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount,
      {bool isGrandTotal = false, required BuildContext context}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.notoSans(
              fontSize: isGrandTotal ? 16 : 14,
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
              color: isGrandTotal ? Colors.black87 : Colors.grey[600],
            ),
          ),
          Text(
            '¥${NumberFormat('#,###').format(amount)}',
            style: GoogleFonts.notoSans(
              fontSize: isGrandTotal ? 18 : 15,
              fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.w500,
              color: isGrandTotal
                  ? Theme.of(context).primaryColor
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.received:
        return '受付';
      case OrderStatus.processing:
        return '処理中';
      case OrderStatus.preparing:
        return '発送準備';
      case OrderStatus.shipped:
        return '発送済み';
      case OrderStatus.cancelled:
        return 'キャンセル';
    }
  }
}

class DeliveryInfo {
  final String name;
  final String postalCode;
  final String address;
  final String phoneNumber;

  DeliveryInfo({
    required this.name,
    required this.postalCode,
    required this.address,
    required this.phoneNumber,
  });
}
