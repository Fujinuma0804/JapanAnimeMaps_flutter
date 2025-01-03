import 'package:flutter/material.dart';

class AddAddress extends StatefulWidget {
  const AddAddress({Key? key}) : super(key: key);

  @override
  State<AddAddress> createState() => _AddAddressState();
}

class _AddAddressState extends State<AddAddress> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '住所の登録',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          children: [
            _buildTextField('姓 (全角)', '例) 田中', _lastNameController, 15),
            _buildTextField('名 (全角)', '例) 太郎', _firstNameController, 15),
            _buildTextField('姓カナ (全角)', '例) タナカ', _lastNameKanaController, 35),
            _buildTextField('名カナ (全角)', '例) タロウ', _firstNameKanaController, 35),
            _buildTextField('郵便番号 (数字)', '例) 1500043', _postalCodeController, 7,
                isNumeric: true),
            _buildDropdown('都道府県', _prefectures, (value) {
              setState(() {
                _selectedPrefecture = value;
              });
            }),
            _buildTextField('市区町村', '例) 渋谷区道玄坂', _cityController, 50),
            _buildTextField('番地', '例)１丁目１０番地８号', _streetaddressController, 50),
            _buildTextField('建物名', '渋谷道玄坂東急ビル2F-C', _buildingController, 50),
            _buildTextField('電話番号', '09012345678', _phoneController, 11),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Handle form submission
                print('保存');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('保存', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint,
      TextEditingController controller, int maxLength,
      {bool isNumeric = false}) {
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
          child: TextField(
            controller: controller,
            maxLength: maxLength,
            cursorColor: Colors.black,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            style: TextStyle(color: Colors.black),
            decoration: InputDecoration(
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey),
              counterText: '',
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.black,
                ),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDropdown(
      String label, List<String> items, ValueChanged<String?> onChanged) {
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
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField<String>(
            value: _selectedPrefecture,
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: TextStyle(color: Colors.black)),
              );
            }).toList(),
            onChanged: onChanged,
            dropdownColor: Colors.white,
            style: TextStyle(color: Colors.black),
            decoration: InputDecoration(
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }
}
