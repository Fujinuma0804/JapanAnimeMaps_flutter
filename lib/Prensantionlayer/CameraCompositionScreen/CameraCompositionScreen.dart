import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:parts/Dataprovider/model/sacred_site_model.dart';
import 'package:parts/Prensantionlayer/CameraCompositionScreen/Capturevideo_image.dart';

class CreateBookmarkPage extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const CreateBookmarkPage({super.key, this.onBackPressed});
  @override
  _CreateBookmarkPageState createState() => _CreateBookmarkPageState();
}

class _CreateBookmarkPageState extends State<CreateBookmarkPage> {
  File? _selectedImage;
  SacredSite? _selectedSacredSite;
  Uint8List? _sacredSiteImageBytes;
  bool _isLoading = true;
  final TextEditingController _titleController = TextEditingController();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  String _selectedPrefecture = '選択してください';

  // Date variables
  DateTime? _startDate;
  DateTime? _endDate;
  String _duration = '';
  String _time = '(23:51)'; // Default time

  final List<String> _prefectures = [
    '選択してください',
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
    '沖縄県'
  ];

  Future<void> _pickImage() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showSnackBar('カメラが見つかりません');
        return;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraCaptureScreen(
            camera: cameras.first,
            initialSacredSite: _selectedSacredSite,
            sacredSiteImageBytes: _sacredSiteImageBytes,
            onSacredSiteSelected: (site) => _loadSacredSiteImageFromUrl(site),
          ),
        ),
      );

      if (result != null && result is File) {
        setState(() {
          _selectedImage = result;
        });
      } else if (result != null) {
        print('Received unexpected result type: ${result.runtimeType}');
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar('画像の選択中にエラーが発生しました');

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    }
  }

  Future<void> _loadSacredSiteImageFromUrl(SacredSite site) async {
    try {
      setState(() => _isLoading = true);
      String imageUrl = site.imageUrl;
      if (imageUrl.startsWith('gs://')) {
        final ref = _storage.refFromURL(imageUrl);
        imageUrl = await ref.getDownloadURL();
      }

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        setState(() {
          _sacredSiteImageBytes = response.bodyBytes;
          _selectedSacredSite = site;
        });
      }
    } catch (e) {
      print('Error loading image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  // Date Picker Functions
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      currentDate: DateTime.now(),
      saveText: '保存',
      confirmText: '確認',
      cancelText: 'キャンセル',
      helpText: '日程を選択',
      errorFormatText: '無効な形式',
      errorInvalidText: '無効な範囲',
      errorInvalidRangeText: '無効な期間',
      fieldStartLabelText: '開始日',
      fieldEndLabelText: '終了日',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _calculateDuration();
      });
    }
  }

  void _calculateDuration() {
    if (_startDate != null && _endDate != null) {
      final difference = _endDate!.difference(_startDate!).inDays + 1;
      setState(() {
        _duration = '期限：${difference}日期';
      });
    }
  }

  String _formatDateRange() {
    if (_startDate == null && _endDate == null) {
      return '日付を選択';
    } else if (_endDate == null) {
      return DateFormat('MM月dd日').format(_startDate!);
    } else {
      final start = DateFormat('MM月dd日').format(_startDate!);
      final end = DateFormat('MM月dd日').format(_endDate!);
      return '$start〜$end';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildCustomAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnailSection(),
            Divider(height: 40),
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: _buildTitleSectionContent(),
              ),
            ),
            SizedBox(height: 24),
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: _buildScheduleSectionContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildCustomAppBar() {
    return PreferredSize(
      preferredSize: Size.fromHeight(56.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2.0,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black),
                  onPressed:
                      widget.onBackPressed ?? () => Navigator.pop(context),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '新しいしおりを作成',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 50,
                  height: 30,
                  decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'サムネイル画像 （任意）',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _selectedImage == null
              ? _buildNoImageState()
              : _buildImagePreview(),
        ),
      ],
    );
  }

  Widget _buildNoImageState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.photo, size: 48, color: Colors.grey.shade400),
        SizedBox(height: 8),
        Text(
          'No Image',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: Icon(Icons.add_photo_alternate),
          label: Text('画像を追加'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: _removeImage,
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: ElevatedButton.icon(
            onPressed: _pickImage,
            icon: Icon(Icons.edit, size: 16),
            label: Text('変更'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'タイトル',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: '例：沖縄（家族旅行）',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade100, // soft gray background
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none, // removes border
            ),
          ),
        ),
        SizedBox(height: 16),
        Text(
          '旅行先の都道府県・国を選択',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100, // soft background
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPrefecture,
              isExpanded: true,
              dropdownColor: Colors.white,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade600),
              items: _prefectures.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedPrefecture = newValue!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleSectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
                onTap: _selectDateRange,
                child: Icon(Icons.calendar_today, size: 20, color: Colors.red)),
            SizedBox(width: 8),
            Text(
              '日程',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        GestureDetector(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _formatDateRange(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color:
                              _startDate == null ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey),
                    if (_duration.isNotEmpty) ...[
                      Text(
                        _duration,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                    ],
                    Text(
                      _time,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                // SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'タップして日程を選択',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _createBookmark,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'しおりを作成',
            style: TextStyle(fontSize: 16),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _createBookmark() {
    if (_titleController.text.isEmpty) {
      _showSnackBar('タイトルを入力してください');
      return;
    }

    if (_selectedPrefecture == '選択してください') {
      _showSnackBar('旅行先を選択してください');
      return;
    }

    if (_startDate == null || _endDate == null) {
      _showSnackBar('日程を選択してください');
      return;
    }

    final bookmarkData = {
      'image': _selectedImage?.path,
      'title': _titleController.text,
      'prefecture': _selectedPrefecture,
      'schedule': _formatDateRange(),
      'duration': _duration,
    };

    print('しおりを作成: $bookmarkData');
    _showSnackBar('しおりを作成しました！');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
