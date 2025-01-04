import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UpdateAddress extends StatefulWidget {
  final String addressId;
  const UpdateAddress({Key? key, required this.addressId}) : super(key: key);

  @override
  State<UpdateAddress> createState() => _UpdateAddressState();
}

class _UpdateAddressState extends State<UpdateAddress> {
  final _formKey = GlobalKey<FormState>();
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameKanaController = TextEditingController();
  final _firstNameKanaController = TextEditingController();
  final _postalCodeController = TextEditingController();
  String? _selectedPrefecture;
  final _cityController = TextEditingController();
  final _streetaddressController = TextEditingController();
  final _buildingController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = true;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _prefectures = [
    '北海道',
    '青森県',
    '岩手県',
    '宮城県',
    '秋田県',
    '山形県',
    '福島県',
    '茨城県',
    '栃木県',
    '群馬県',
    '埼玉県',
    '千葉県',
    '東京都',
    '神奈川県',
    '新潟県',
    '富山県',
    '石川県',
    '福井県',
    '山梨県',
    '長野県',
    '岐阜県',
    '静岡県',
    '愛知県',
    '三重県',
    '滋賀県',
    '京都府',
    '大阪府',
    '兵庫県',
    '奈良県',
    '和歌山県',
    '鳥取県',
    '島根県',
    '岡山県',
    '広島県',
    '山口県',
    '徳島県',
    '香川県',
    '愛媛県',
    '高知県',
    '福岡県',
    '佐賀県',
    '長崎県',
    '熊本県',
    '大分県',
    '宮崎県',
    '鹿児島県',
    '沖縄県',
  ];

  // 正規表現パターン
  final _kanjiPattern = RegExp(r'^[一-龯々]+$');
  final _kanaPattern = RegExp(r'^[ァ-ヶー]+$');
  final _postalCodePattern = RegExp(r'^\d{7}$');
  final _phonePattern = RegExp(r'^\d{10,11}$');

  @override
  void initState() {
    super.initState();
    _postalCodeController.addListener(_onPostalCodeChanged);
    _loadAddressData();
  }

  @override
  void dispose() {
    _postalCodeController.removeListener(_onPostalCodeChanged);
    _lastNameController.dispose();
    _firstNameController.dispose();
    _lastNameKanaController.dispose();
    _firstNameKanaController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _streetaddressController.dispose();
    _buildingController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // 住所データの読み込み
  Future<void> _loadAddressData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        _showErrorDialog('ユーザーがログインしていません');
        return;
      }

      final docSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('user_addresses')
          .doc(widget.addressId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        setState(() {
          _lastNameController.text = data['lastName'] ?? '';
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameKanaController.text = data['lastNameKana'] ?? '';
          _firstNameKanaController.text = data['firstNameKana'] ?? '';
          _postalCodeController.text = data['postalCode'] ?? '';
          _selectedPrefecture = data['prefecture'];
          _cityController.text = data['city'] ?? '';
          _streetaddressController.text = data['streetAddress'] ?? '';
          _buildingController.text = data['building'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _isLoading = false;
        });
      } else {
        _showErrorDialog('住所データが見つかりません');
      }
    } catch (e) {
      _showErrorDialog('データの読み込み中にエラーが発生しました: ${e.toString()}');
    }
  }

  // 入力値の検証メソッド
  String? validateKanji(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldNameを入力してください';
    }
    if (!_kanjiPattern.hasMatch(value)) {
      return '$fieldNameは漢字で入力してください';
    }
    return null;
  }

  String? validateKana(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldNameを入力してください';
    }
    if (!_kanaPattern.hasMatch(value)) {
      return '$fieldNameはカタカナで入力してください';
    }
    return null;
  }

  String? validatePostalCode(String? value) {
    if (value == null || value.isEmpty) {
      return '郵便番号を入力してください';
    }
    if (!_postalCodePattern.hasMatch(value)) {
      return '郵便番号は7桁の数字で入力してください';
    }
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return '電話番号を入力してください';
    }
    if (!_phonePattern.hasMatch(value)) {
      return '電話番号は10桁または11桁の数字で入力してください';
    }
    return null;
  }

  String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldNameを入力してください';
    }
    return null;
  }

  Future<void> _onPostalCodeChanged() async {
    final postalCode = _postalCodeController.text;
    if (postalCode.length == 7 && int.tryParse(postalCode) != null) {
      try {
        final response = await http.get(
          Uri.parse(
              'https://zipcloud.ibsnet.co.jp/api/search?zipcode=$postalCode'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['results'] != null && data['results'].isNotEmpty) {
            final address = data['results'][0];
            final prefecture = '${address['address1']}';

            // 都道府県名を正規化
            String normalizedPrefecture = prefecture;
            if (!prefecture.endsWith('都') &&
                !prefecture.endsWith('府') &&
                !prefecture.endsWith('県')) {
              normalizedPrefecture = '$prefecture県';
            }

            // _prefecturesリストから完全一致する都道府県を探す
            final matchedPrefecture = _prefectures.firstWhere(
              (pref) => pref == normalizedPrefecture,
              orElse: () => _prefectures[0],
            );

            setState(() {
              _selectedPrefecture = matchedPrefecture;
              _cityController.text = address['address2'] ?? '';
              _streetaddressController.text = address['address3'] ?? '';
            });
          } else {
            _showErrorDialog('該当する住所が見つかりませんでした');
          }
        } else {
          _showErrorDialog('住所の取得に失敗しました');
        }
      } catch (e) {
        _showErrorDialog('エラーが発生しました: ${e.toString()}');
      }
    }
  }

  // Firebase への更新処理
  Future<void> _updateAddress() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        _showErrorDialog('ユーザーがログインしていません');
        return;
      }

      final addressData = {
        'lastName': _lastNameController.text,
        'firstName': _firstNameController.text,
        'lastNameKana': _lastNameKanaController.text,
        'firstNameKana': _firstNameKanaController.text,
        'postalCode': _postalCodeController.text,
        'prefecture': _selectedPrefecture,
        'city': _cityController.text,
        'streetAddress': _streetaddressController.text,
        'building': _buildingController.text,
        'phoneNumber': _phoneController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('user_addresses')
          .doc(widget.addressId)
          .update(addressData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('住所を更新しました')),
      );
      Navigator.pop(context);
    } catch (e) {
      _showErrorDialog('更新中にエラーが発生しました: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('エラー'),
        content: Text(message),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            '住所の変更',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '住所の変更',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildValidatedTextField(
                '姓 (漢字)',
                '例) 田中',
                _lastNameController,
                15,
                validator: (value) => validateKanji(value, '姓'),
              ),
              _buildValidatedTextField(
                '名 (漢字)',
                '例) 太郎',
                _firstNameController,
                15,
                validator: (value) => validateKanji(value, '名'),
              ),
              _buildValidatedTextField(
                '姓 (カタカナ)',
                '例) タナカ',
                _lastNameKanaController,
                35,
                validator: (value) => validateKana(value, '姓カナ'),
              ),
              _buildValidatedTextField(
                '名 (カタカナ)',
                '例) タロウ',
                _firstNameKanaController,
                35,
                validator: (value) => validateKana(value, '名カナ'),
              ),
              _buildValidatedTextField(
                '郵便番号',
                '例) 1500043',
                _postalCodeController,
                7,
                isNumeric: true,
                validator: validatePostalCode,
              ),
              _buildValidatedDropdown(),
              _buildValidatedTextField(
                '市区町村',
                '例) 渋谷区道玄坂',
                _cityController,
                50,
                validator: (value) => validateRequired(value, '市区町村'),
              ),
              _buildValidatedTextField(
                '番地',
                '例) １丁目１０番地８号',
                _streetaddressController,
                50,
                validator: (value) => validateRequired(value, '番地'),
              ),
              _buildValidatedTextField(
                '建物名（部屋番号がある場合は入力してください。）',
                '例) 渋谷道玄坂東急ビル2F-C',
                _buildingController,
                50,
              ),
              _buildValidatedTextField(
                '電話番号',
                '例) 09012345678',
                _phoneController,
                11,
                isNumeric: true,
                validator: validatePhone,
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 50.0,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      _updateAddress();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00008b),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '住所を更新',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidatedTextField(
    String label,
    String hint,
    TextEditingController controller,
    int maxLength, {
    bool isNumeric = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            controller: controller,
            maxLength: maxLength,
            cursorColor: Colors.black,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            style: TextStyle(color: Colors.black),
            validator: validator,
            decoration: InputDecoration(
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey),
              counterText: '',
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              errorStyle: TextStyle(color: Colors.red),
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildValidatedDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '都道府県',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField<String>(
            value: _selectedPrefecture,
            items: _prefectures.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: TextStyle(color: Colors.black)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPrefecture = value;
              });
            },
            validator: (value) => validateRequired(value, '都道府県'),
            dropdownColor: Colors.white,
            style: TextStyle(color: Colors.black),
            decoration: InputDecoration(
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              errorStyle: TextStyle(color: Colors.red),
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }
}
