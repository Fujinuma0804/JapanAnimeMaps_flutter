import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:parts/shop/shop_welcome/delivery_instructions_page.dart';
import 'package:parts/shop/shop_welcome/prefectures.dart';

class DeliveryInfoForm extends StatefulWidget {
  const DeliveryInfoForm({super.key});

  @override
  State<DeliveryInfoForm> createState() => _DeliveryInfoFormState();
}

class _DeliveryInfoFormState extends State<DeliveryInfoForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _streetController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _buildingController = TextEditingController();
  String? _selectedPrefecture;
  bool _isLoading = false;
  String? _deliveryInstructions;

  // 都道府県リスト
  final List<String> _prefectures = prefectures;

  @override
  void dispose() {
    _buildingController.dispose();
    _nameController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    super.dispose();
  }

  // 郵便番号からの住所取得
  Future<void> _fetchAddress(String postalCode) async {
    if (postalCode.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ハイフンを除去
      final cleanPostalCode = postalCode.replaceAll('-', '');

      final response = await http.get(
        Uri.parse(
            'https://zipcloud.ibsnet.co.jp/api/search?zipcode=$cleanPostalCode'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null && data['results'].length > 0) {
          final address = data['results'][0];
          setState(() {
            _selectedPrefecture = address['address1'];
            _cityController.text = address['address2'];
            // address3があれば市区町村に追加
            if (address['address3'] != null && address['address3'].isNotEmpty) {
              _cityController.text += address['address3'];
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('該当する住所が見つかりませんでした')),
          );
        }
      } else {
        throw Exception('住所の取得に失敗しました');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('エラーが発生しました。しばらく経ってから再度お試しください。'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '配送先登録',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: Form(
          key: _formKey,
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 氏名入力
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '氏名',
                        hintText: '山田 太郎',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '氏名を入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // 郵便番号入力
                    TextFormField(
                      controller: _postalCodeController,
                      decoration: InputDecoration(
                        labelText: '郵便番号',
                        hintText: '123-4567',
                        border: const OutlineInputBorder(),
                        filled: true,
                        suffixIcon: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                        LengthLimitingTextInputFormatter(8),
                      ],
                      onChanged: (value) {
                        // ハイフンの自動挿入
                        if (value.length == 3 && !value.contains('-')) {
                          _postalCodeController.text = '$value-';
                          _postalCodeController.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                                offset: _postalCodeController.text.length),
                          );
                        }
                        // 郵便番号が完全な形式（XXX-XXXX）になったら住所を自動取得
                        if (RegExp(r'^\d{3}-\d{4}$').hasMatch(value)) {
                          _fetchAddress(value);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '郵便番号を入力してください';
                        }
                        if (!RegExp(r'^\d{3}-\d{4}$').hasMatch(value)) {
                          return '正しい形式で入力してください (例: 123-4567)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // 都道府県選択
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: '都道府県',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      value: _selectedPrefecture,
                      items: _prefectures.map((String prefecture) {
                        return DropdownMenuItem<String>(
                          value: prefecture,
                          child: Text(prefecture),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedPrefecture = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '都道府県を選択してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // 市区町村入力
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: '市区町村',
                        hintText: '渋谷区代々木',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '市区町村を入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // 番地、建物名等
                    TextFormField(
                      controller: _streetController,
                      decoration: const InputDecoration(
                        labelText: '丁目、番地、号',
                        hintText: '1-2-3',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9０-９一二三四五六七八九十\-ー丁目番地号]')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '番地を入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _buildingController,
                      decoration: const InputDecoration(
                        labelText: '建物名・部屋番号(任意)',
                        hintText: 'アニメマンション101号室',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 電話番号1入力
                    TextFormField(
                      controller: _phone1Controller,
                      decoration: const InputDecoration(
                        labelText: '電話番号1',
                        hintText: '090-1234-5678',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                        LengthLimitingTextInputFormatter(13),
                      ],
                      onChanged: (value) {
                        // ハイフンの自動挿入
                        if (value.length == 3 && !value.contains('-')) {
                          _phone1Controller.text = '$value-';
                          _phone1Controller.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: _phone1Controller.text.length),
                          );
                        } else if (value.length == 8 &&
                            value.split('-').length == 2) {
                          _phone1Controller.text = '${value}-';
                          _phone1Controller.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: _phone1Controller.text.length),
                          );
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '電話番号を入力してください';
                        }
                        if (!RegExp(r'^\d{2,4}-\d{2,4}-\d{4}$')
                            .hasMatch(value)) {
                          return '正しい形式で入力してください (例: 090-1234-5678)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // 電話番号2入力（任意）
                    TextFormField(
                      controller: _phone2Controller,
                      decoration: const InputDecoration(
                        labelText: '電話番号2（任意）',
                        hintText: '090-1234-5678',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                        LengthLimitingTextInputFormatter(13),
                      ],
                      onChanged: (value) {
                        // ハイフンの自動挿入
                        if (value.length == 3 && !value.contains('-')) {
                          _phone2Controller.text = '$value-';
                          _phone2Controller.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: _phone2Controller.text.length),
                          );
                        } else if (value.length == 8 &&
                            value.split('-').length == 2) {
                          _phone2Controller.text = '${value}-';
                          _phone2Controller.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: _phone2Controller.text.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // 配送指示ボタン
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const DeliveryInstructionsPage(),
                            ),
                          );

                          if (result != null) {
                            setState(() {
                              _deliveryInstructions = result as String;
                            });
                          }
                        },
                        icon: const Icon(Icons.local_shipping),
                        label: const Text('配送指示を入力'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 登録ボタン
                    Center(
                      child: SizedBox(
                        width: 200, // ボタンの幅を制限
                        child: FilledButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              try {
                                // 現在のユーザーを取得
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('ユーザーがログインしていません')),
                                  );
                                  return;
                                }

                                // Firestoreのインスタンスを取得
                                final firestore = FirebaseFirestore.instance;

                                // 住所データを作成
                                final addressData = {
                                  'addressname': _nameController.text,
                                  'postalCode': _postalCodeController.text,
                                  'prefecture': _selectedPrefecture,
                                  'city': _cityController.text,
                                  'street': _streetController.text,
                                  'building':
                                      _buildingController.text.isNotEmpty
                                          ? null
                                          : _buildingController.text,
                                  'phone1': _phone1Controller.text,
                                  'phone2': _phone2Controller.text.isEmpty
                                      ? null
                                      : _phone2Controller.text,
                                  'deliveryInstructions': _deliveryInstructions,
                                  'createdAt': FieldValue.serverTimestamp(),
                                };

                                // ユーザーのaddressコレクションに保存
                                await firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('address')
                                    .add(addressData);

                                // 登録成功時の画像表示
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext context) {
                                      return Dialog(
                                        backgroundColor: Colors.transparent,
                                        elevation: 0,
                                        child: Image.asset(
                                          'assets/images/checking_boxes_rafiki.png',
                                          width: 200,
                                          height: 200,
                                          fit: BoxFit.contain,
                                        ),
                                      );
                                    },
                                  );

                                  // 2秒後に自動で閉じる
                                  Future.delayed(const Duration(seconds: 2),
                                      () {
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  });
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('エラーが発生しました: ${e.toString()}')),
                                );
                              }
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00008b),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            '登録',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]))),
    );
  }
}
