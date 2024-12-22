import 'package:flutter/material.dart';

class DeliveryInstructionsPage extends StatefulWidget {
  const DeliveryInstructionsPage({super.key});

  @override
  State<DeliveryInstructionsPage> createState() =>
      _DeliveryInstructionsPageState();
}

class _DeliveryInstructionsPageState extends State<DeliveryInstructionsPage> {
  final _formKey = GlobalKey<FormState>();
  String? _deliveryType;
  final Set<String> _selectedLocations = {};
  final _otherInstructionsController = TextEditingController();

  // 置き配場所のオプション
  final List<Map<String, String>> _deliveryLocations = [
    {'value': 'entrance', 'label': '玄関', 'icon': 'assets/icons/entrance.png'},
    {
      'value': 'delivery_box',
      'label': '宅配ボックス',
      'icon': 'assets/icons/box.png'
    },
    {
      'value': 'gas_meter',
      'label': 'ガスメーターボックス',
      'icon': 'assets/icons/gas.png'
    },
  ];

  @override
  void dispose() {
    _otherInstructionsController.dispose();
    super.dispose();
  }

  // 選択された置き配場所を文字列に変換
  String get _selectedLocationsText {
    if (_selectedLocations.isEmpty) return '';
    return _selectedLocations.join('、');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('配送指示'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // お届け先種別
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.home_outlined),
                          const SizedBox(width: 8),
                          const Text(
                            'お届け先種別',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            ' *',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      ...['戸建て住居', '集合住宅', 'その他'].map(
                        (type) => RadioListTile<String>(
                          title: Text(type),
                          value: type,
                          groupValue: _deliveryType,
                          onChanged: (value) {
                            setState(() {
                              _deliveryType = value;
                            });
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                        ),
                      ),
                      if (_deliveryType == null)
                        const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Text(
                            'お届け先種別を選択してください',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 置き配指定
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined),
                          const SizedBox(width: 8),
                          const Text(
                            '置き配指定',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            ' *',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      ..._deliveryLocations.map(
                        (location) => CheckboxListTile(
                          title: Text(location['label']!),
                          value: _selectedLocations.contains(location['value']),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value ?? false) {
                                _selectedLocations.add(location['value']!);
                              } else {
                                _selectedLocations.remove(location['value']);
                              }
                            });
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                        ),
                      ),
                      if (_selectedLocations.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Text(
                            '置き配場所を1つ以上選択してください',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // その他指示
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.note_outlined),
                          const SizedBox(width: 8),
                          const Text(
                            'その他指示',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            ' (任意)',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      TextFormField(
                        controller: _otherInstructionsController,
                        decoration: const InputDecoration(
                          hintText: '配送に関する特記事項があればご記入ください',
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                        maxLines: 3,
                        maxLength: 200,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 保存ボタン
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_deliveryType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('お届け先種別を選択してください'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (_selectedLocations.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('置き配場所を1つ以上選択してください'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // 入力データを作成
                    final deliveryInstructions = {
                      'deliveryType': _deliveryType,
                      'locations': _selectedLocationsText,
                      'otherInstructions': _otherInstructionsController.text,
                    };

                    // 前の画面に戻る
                    Navigator.pop(context, deliveryInstructions);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
