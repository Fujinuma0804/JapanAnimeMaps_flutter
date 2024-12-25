import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parts/shop/services/postal_code_service.dart';

class DeliveryAddress {
  final String? id;
  final String name;
  final String phoneNumber;
  final String postalCode;
  final String prefecture;
  final String city;
  final String street;
  final String? building;
  final String label;

  DeliveryAddress({
    this.id,
    required this.name,
    required this.phoneNumber,
    required this.postalCode,
    required this.prefecture,
    required this.city,
    required this.street,
    this.building,
    required this.label,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'postalCode': postalCode,
      'prefecture': prefecture,
      'city': city,
      'street': street,
      'building': building,
      'label': label,
    };
  }

  factory DeliveryAddress.fromMap(Map<String, dynamic> map, String id) {
    return DeliveryAddress(
      id: id,
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      postalCode: map['postalCode'] ?? '',
      prefecture: map['prefecture'] ?? '',
      city: map['city'] ?? '',
      street: map['street'] ?? '',
      building: map['building'],
      label: map['label'] ?? '',
    );
  }
}

class AddressListScreen extends StatelessWidget {
  const AddressListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          '配送先住所',
          style: GoogleFonts.notoSans(
            fontWeight: FontWeight.w600,
            color: Color(0xFF00008B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF00008B),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('user_addresses')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return _buildLoadingState();
          }

          final addresses = snapshot.data!.docs
              .map((doc) => DeliveryAddress.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ))
              .toList();

          if (addresses.isEmpty) {
            return _buildEmptyState(context);
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final address = addresses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _AddressCard(
                          address: address,
                          onEdit: () => _editAddress(context, address),
                          onDelete: () => _deleteAddress(context, address.id!),
                        ),
                      );
                    },
                    childCount: addresses.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAddress(context),
        backgroundColor: Color(0xFF00008B),
        label: Text(
          '新規住所を追加',
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        icon: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            '配送先住所が登録されていません',
            style: GoogleFonts.notoSans(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'エラーが発生しました',
            style: GoogleFonts.notoSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addAddress(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressFormScreen(),
      ),
    );
  }

  Future<void> _editAddress(
      BuildContext context, DeliveryAddress address) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressFormScreen(address: address),
      ),
    );
  }

  Future<void> _deleteAddress(BuildContext context, String addressId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '住所を削除',
          style: GoogleFonts.notoSans(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'この配送先住所を削除してもよろしいですか？',
          style: GoogleFonts.notoSans(),
        ),
        actions: [
          TextButton(
            child: const Text('キャンセル'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text(
              '削除',
              style: GoogleFonts.notoSans(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = FirebaseAuth.instance.currentUser;
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('user_addresses')
            .doc(addressId)
            .delete();

        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('住所を削除しました')),
        );
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }
}

class _AddressCard extends StatelessWidget {
  final DeliveryAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressCard({
    Key? key,
    required this.address,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAddressLabel(address.label),
                    const Spacer(),
                    _buildActionButtons(),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAddressInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressLabel(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSans(
          color: Colors.blue[700],
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
          tooltip: '編集',
          color: Colors.grey[700],
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
          tooltip: '削除',
          color: Colors.red[400],
        ),
      ],
    );
  }

  Widget _buildAddressInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          address.name,
          style: GoogleFonts.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          address.phoneNumber,
          style: GoogleFonts.notoSans(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '〒${address.postalCode}',
          style: GoogleFonts.notoSans(
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${address.prefecture}${address.city}${address.street}',
          style: GoogleFonts.notoSans(
            fontSize: 14,
          ),
        ),
        if (address.building != null && address.building!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            address.building!,
            style: GoogleFonts.notoSans(
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}

class AddressFormScreen extends StatefulWidget {
  final DeliveryAddress? address;

  const AddressFormScreen({Key? key, this.address}) : super(key: key);

  @override
  _AddressFormScreenState createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _prefectureController;
  late final TextEditingController _cityController;
  late final TextEditingController _streetController;
  late final TextEditingController _buildingController;
  late final TextEditingController _labelController;
  final _postalCodeService = PostalCodeService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.address?.name);
    _phoneController = TextEditingController(text: widget.address?.phoneNumber);
    _postalCodeController =
        TextEditingController(text: widget.address?.postalCode);
    _prefectureController =
        TextEditingController(text: widget.address?.prefecture);
    _cityController = TextEditingController(text: widget.address?.city);
    _streetController = TextEditingController(text: widget.address?.street);
    _buildingController = TextEditingController(text: widget.address?.building);
    _labelController = TextEditingController(text: widget.address?.label);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _postalCodeController.dispose();
    _prefectureController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.address == null ? '新規住所登録' : '住所を編集',
          style: GoogleFonts.notoSans(
            fontWeight: FontWeight.w600,
            color: Color(0xFF00008B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.close,
            color: Color(0xFF00008B),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildFormSection(
                    title: '基本情報',
                    children: [
                      _CustomTextField(
                        controller: _labelController,
                        label: 'ラベル',
                        hintText: '自宅、会社など',
                        prefixIcon: Icons.label_outline,
                      ),
                      const SizedBox(height: 16),
                      _CustomTextField(
                        controller: _nameController,
                        label: '氏名',
                        hintText: '山田 太郎',
                        prefixIcon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _CustomTextField(
                        controller: _phoneController,
                        label: '電話番号',
                        hintText: '090-1234-5678',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildFormSection(
                    title: '住所情報',
                    children: [
                      _CustomTextField(
                        controller: _postalCodeController,
                        label: '郵便番号',
                        hintText: '123-4567',
                        prefixIcon: Icons.location_on_outlined,
                        keyboardType: TextInputType.number,
                        suffixIcon: _buildPostalCodeLookupButton(),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(7),
                          _PostalCodeFormatter(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _CustomTextField(
                        controller: _prefectureController,
                        label: '都道府県',
                        hintText: '東京都',
                        prefixIcon: Icons.map_outlined,
                      ),
                      const SizedBox(height: 16),
                      _CustomTextField(
                        controller: _cityController,
                        label: '市区町村',
                        hintText: '渋谷区',
                        prefixIcon: Icons.location_city_outlined,
                      ),
                      const SizedBox(height: 16),
                      _CustomTextField(
                        controller: _streetController,
                        label: '番地',
                        hintText: '1-2-3',
                        prefixIcon: Icons.home_outlined,
                      ),
                      const SizedBox(height: 16),
                      _CustomTextField(
                        controller: _buildingController,
                        label: '建物名・部屋番号',
                        hintText: '〇〇マンション101',
                        prefixIcon: Icons.business_outlined,
                        required: false,
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildFormSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.notoSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildPostalCodeLookupButton() {
    return TextButton(
      onPressed: _isLoading ? null : _lookupAddress,
      child: Text(
        '住所検索',
        style: GoogleFonts.notoSans(
          color: Color(0xFF00008B),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00008B),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.address == null ? '登録する' : '更新する',
                  style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _lookupAddress() async {
    final postalCode = _postalCodeController.text.replaceAll('-', '');

    if (postalCode.length != 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正しい郵便番号を入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final address = await _postalCodeService.getAddress(postalCode);

      if (address == null) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('該当する住所が見つかりませんでした'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _prefectureController.text = address.prefecture;
        _cityController.text = address.city;
        _streetController.text = address.street;
      });
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('住所の取得に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final address = DeliveryAddress(
        id: widget.address?.id,
        name: _nameController.text,
        phoneNumber: _phoneController.text,
        postalCode: _postalCodeController.text.replaceAll('-', ''),
        prefecture: _prefectureController.text,
        city: _cityController.text,
        street: _streetController.text,
        building: _buildingController.text,
        label: _labelController.text,
      );

      final addressesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('user_addresses');

      if (widget.address == null) {
        await addressesRef.add(address.toMap());
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配送先住所を追加しました')),
        );
      } else {
        await addressesRef.doc(widget.address!.id).update(address.toMap());
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配送先住所を更新しました')),
        );
      }

      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool required;

  const _CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.required = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              if (required)
                TextSpan(
                  text: ' *',
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '$labelを入力してください';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }
}

class _PostalCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.length > 3 && !text.contains('-')) {
      final formattedText = '${text.substring(0, 3)}-${text.substring(3)}';
      return TextEditingValue(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length),
      );
    }
    return newValue;
  }
}
