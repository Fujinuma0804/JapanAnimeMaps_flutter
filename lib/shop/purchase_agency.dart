import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  bool _prohibitedItemsConfirmed = false;
  bool _stockCheckConfirmed = false;
  bool _purchaseConditionsConfirmed = false;
  bool _outOfStockConfirmed = false;
  bool _processConfirmed = false;
  bool _scheduleConfirmed = false;
  bool _estimateConfirmed = false;
  File? _userImage;

  final TextEditingController _StorePlaceCommentController =
      TextEditingController();
  final TextEditingController _ProductCommentController =
      TextEditingController();
  final TextEditingController _PriceCommentController = TextEditingController();
  final TextEditingController _optionalCommentController =
      TextEditingController();
  final TextEditingController _SoldoutCommentController =
      TextEditingController();
  static const int _maxLength = 500;

  Future<void> _pickImage(bool fromCamera) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1800,
      maxHeight: 1800,
    );

    if (image != null) {
      setState(() {
        _userImage = File(image.path);
      });
    }
  }

  @override
  void dispose() {
    _StorePlaceCommentController.dispose();
    _ProductCommentController.dispose();
    _PriceCommentController.dispose();
    _SoldoutCommentController.dispose();
    _optionalCommentController.dispose();
    super.dispose();
  }

  bool _canProceed() {
    return _prohibitedItemsConfirmed &&
        _stockCheckConfirmed &&
        _purchaseConditionsConfirmed &&
        _outOfStockConfirmed &&
        _processConfirmed &&
        _scheduleConfirmed &&
        _estimateConfirmed &&
        _StorePlaceCommentController.text.trim().isNotEmpty &&
        _ProductCommentController.text.trim().isNotEmpty &&
        _PriceCommentController.text.trim().isNotEmpty &&
        _SoldoutCommentController.text.trim().isNotEmpty &&
        _userImage != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '確認事項',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStepCircle(true, '同意'),
                  _buildStepLine(),
                  _buildStepCircle(false, '住所'),
                  _buildStepLine(),
                  _buildStepCircle(false, '支払'),
                  _buildStepLine(),
                  _buildStepCircle(false, '確認'),
                  _buildStepLine(),
                  _buildStepCircle(false, '完了'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '確認事項にご回答ください',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildConfirmationSection(
                    '⚠️代行できないお品について',
                    '代行できないお品については、買い物代行トップページの「よくある質問」>「購入できないものはありますか？」をご確認ください。',
                    _prohibitedItemsConfirmed,
                    (value) =>
                        setState(() => _prohibitedItemsConfirmed = value),
                  ),
                  _buildConfirmationSection(
                    '⚠️事前の在庫確認について',
                    '店舗への在庫確認は行っておりません。必ずご自身で在庫確認をお願いします。',
                    _stockCheckConfirmed,
                    (value) => setState(() => _stockCheckConfirmed = value),
                  ),
                  _buildConfirmationSection(
                    '⚠代行するお品について',
                    'お見積もりの段階で、購入の可否を弊社で判断させていただきます。代行をお断りする場合もございます。',
                    _purchaseConditionsConfirmed,
                    (value) =>
                        setState(() => _purchaseConditionsConfirmed = value),
                  ),
                  _buildConfirmationSection(
                    '⚠️在庫がなかった場合について',
                    '手数料(商品代金の20%と交通費)を引いた額をご指定の口座へ返金させていただきます。',
                    _outOfStockConfirmed,
                    (value) => setState(() => _outOfStockConfirmed = value),
                  ),
                  _buildConfirmationSection(
                    '⚠️ご利用までの流れについて',
                    'お申込み後、お見積もりメールと通知が届きます。こちらに承諾いただいた後、スケジュール調整をいたします。',
                    _processConfirmed,
                    (value) => setState(() => _processConfirmed = value),
                  ),
                  _buildConfirmationSection(
                    '⚠スケジュール調整について',
                    '必要な情報が不足している場合は、お見積もりや、その後のスケジュール調整',
                    _scheduleConfirmed,
                    (value) => setState(() => _scheduleConfirmed = value),
                  ),
                  _buildConfirmationSection(
                    '⚠お見積もりについて',
                    'お見積もりの返答について、最長で５営業日ほどお時間をいただく場合がございます。',
                    _estimateConfirmed,
                    (value) => setState(() => _estimateConfirmed = value),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '購入場所について',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00008b),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '必須',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '①店舗名\n②住所（郵便番号含む）をご記入ください。\n※ネットでのご購入は『ネット』とご記入ください。',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _StorePlaceCommentController,
                          maxLength: _maxLength,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: '①店舗名\n②住所（郵便番号含む）',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            counterStyle: TextStyle(color: Colors.grey[600]),
                          ),
                          onChanged: (value) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '品物の確認',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00008b),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '必須',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '①商品名、②金額、③希望個数　④色、サイズ（複数種類ある場合）をご記入ください。',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _ProductCommentController,
                          maxLength: _maxLength,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: '①商品名\n②金額\n③希望個数\n④色・サイズ（ある場合）',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            counterStyle: TextStyle(color: Colors.grey[600]),
                          ),
                          onChanged: (value) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '在庫がなかった場合の対応について',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00008b),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '必須',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '例）『購入不要』/『 M > L > S の順で購入希望』などご記入ください。',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _SoldoutCommentController,
                          maxLength: _maxLength,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: '',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            counterStyle: TextStyle(color: Colors.grey[600]),
                          ),
                          onChanged: (value) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '商品画像',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Color(0xFF00008b),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '必須',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '商品の画像がある場合はアップロードしてください',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(false),
                          icon: Icon(
                            _userImage != null
                                ? Icons.check_circle
                                : Icons.add_photo_alternate,
                            color: _userImage != null
                                ? Colors.green
                                : const Color(0xFF00008b),
                          ),
                          label: Text(
                            _userImage != null ? '撮影した画像を変更' : '撮影した画像をアップロード',
                            style: const TextStyle(
                              color: Color(0xFF00008b),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _userImage != null ? Colors.grey[200] : null,
                          ),
                        ),
                        if (_userImage != null) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _userImage!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '商品代の合計金額',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00008b),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '必須',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '商品代の合計をご記入ください。最低料金(10,000円)にみたない場合には、差額を頂戴いたします。',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _PriceCommentController,
                          maxLength: _maxLength,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: '商品代金',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            counterStyle: TextStyle(color: Colors.grey[600]),
                          ),
                          onChanged: (value) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'その他ご要望',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '任意',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'その他ご要望がございましたらご記入ください',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _optionalCommentController,
                          maxLength: _maxLength,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: '配送時の要望、連絡事項など',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            counterStyle: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _canProceed()
                ? () {
                    // 次の画面への遷移処理
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00008b),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'すべてに同意し進む',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCircle(bool active, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xFF00008b) : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label.characters.take(2).toString(), // 2文字までに制限
            style: TextStyle(
              fontSize: 12,
              color: active ? const Color(0xFF00008b) : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine() {
    return Expanded(
      child: Container(
        height: 2,
        color: Colors.grey[300],
      ),
    );
  }

  Widget _buildConfirmationSection(
    String title,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00008b),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '必須',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => onChanged(!value),
            child: Row(
              children: [
                Checkbox(
                  value: value,
                  onChanged: (newValue) => onChanged(newValue ?? false),
                  activeColor: const Color(0xFF00008b),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Text(
                  '確認しました',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
