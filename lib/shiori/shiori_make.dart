import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

class ShioriMakePage extends StatefulWidget {
  const ShioriMakePage({Key? key}) : super(key: key);

  @override
  State<ShioriMakePage> createState() => _ShioriMakePageState();
}

class _ShioriMakePageState extends State<ShioriMakePage> {
  // コントローラー
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _otherDestinationController = TextEditingController();

  // 状態管理
  DateTime? _departureDate;
  DateTime? _returnDate;
  String _mainDestination = '日本';
  List<String> _countries = ['日本']; // 初期値
  File? _selectedImage;
  bool _isLocked = false;
  bool _isChatDisabled = false;
  String _userLanguage = 'ja'; // デフォルトは日本語
  bool _isLanguageLoaded = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserLanguage();
    _fetchCountries();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _otherDestinationController.dispose();
    super.dispose();
  }

  // Firebaseからユーザーの言語設定を取得
  Future<void> _loadUserLanguage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('=== 言語設定取得開始 ===');
        print('ユーザーID: ${user.uid}');

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null && userData.containsKey('language')) {
            final language = userData['language'] as String;
            print('Firebaseから取得した言語設定: $language');

            setState(() {
              _userLanguage = language;
              _isLanguageLoaded = true;
            });
          } else {
            print('言語設定が見つからないため、デフォルト値を使用: ja');
            setState(() {
              _userLanguage = 'ja';
              _isLanguageLoaded = true;
            });
          }
        } else {
          print('ユーザードキュメントが存在しないため、デフォルト値を使用: ja');
          setState(() {
            _userLanguage = 'ja';
            _isLanguageLoaded = true;
          });
        }
        print('=== 言語設定取得完了 ===');
      } else {
        print('ユーザーが認証されていないため、デフォルト値を使用: ja');
        setState(() {
          _userLanguage = 'ja';
          _isLanguageLoaded = true;
        });
      }
    } catch (e) {
      print('言語設定取得エラー: $e');
      setState(() {
        _userLanguage = 'ja';
        _isLanguageLoaded = true;
      });
    }
  }

  // 言語に応じたテキストを取得
  String _getLocalizedText(String key) {
    final texts = {
      'ja': {
        'selectDate': '日付を選択してください',
        'selectDepartureDate': '出発日を選択',
        'selectReturnDate': '帰宅日を選択',
        'departureDate': '出発日',
        'returnDate': '帰宅日',
        'cancel': 'キャンセル',
        'confirm': '決定',
        'year': '年',
        'month': '月',
        'day': '日',
      },
      'en': {
        'selectDate': 'Please select a date',
        'selectDepartureDate': 'Select Departure Date',
        'selectReturnDate': 'Select Return Date',
        'departureDate': 'Departure Date',
        'returnDate': 'Return Date',
        'cancel': 'Cancel',
        'confirm': 'Confirm',
        'year': '',
        'month': '',
        'day': '',
      },
    };

    return texts[_userLanguage]?[key] ?? texts['ja']![key]!;
  }

  // 日付を言語に応じてフォーマット
  String _formatDate(DateTime date) {
    if (_userLanguage == 'ja') {
      return '${date.year}${_getLocalizedText('year')}${date.month}${_getLocalizedText('month')}${date.day}${_getLocalizedText('day')}';
    } else {
      return DateFormat('MMM dd, yyyy', 'en_US').format(date);
    }
  }

  // 国のリストをAPIから取得
  Future<void> _fetchCountries() async {
    print('=== 国リスト取得開始 ===');
    try {
      final url = 'https://restcountries.com/v3.1/all?fields=name,translations';
      print('リクエストURL: $url');

      final response = await http.get(Uri.parse(url));
      print('レスポンスステータス: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('取得した国数: ${data.length}');

        final List<String> countries = [];

        for (var country in data) {
          String countryName;

          if (_userLanguage == 'ja') {
            // 日本語名を取得
            if (country['translations'] != null &&
                country['translations']['jpn'] != null &&
                country['translations']['jpn']['common'] != null) {
              countryName = country['translations']['jpn']['common'] as String;
            } else {
              continue; // 日本語名がない場合はスキップ
            }
          } else {
            // 英語名を取得
            if (country['name'] != null && country['name']['common'] != null) {
              countryName = country['name']['common'] as String;
            } else {
              continue; // 英語名がない場合はスキップ
            }
          }

          countries.add(countryName);
        }

        // 日本を除いてソート
        final defaultCountry = _userLanguage == 'ja' ? '日本' : 'Japan';
        countries.removeWhere((country) => country == defaultCountry);
        countries.sort();

        // デフォルト国を1番上に追加
        countries.insert(0, defaultCountry);

        print('最終的な国リスト（最初の10カ国）: ${countries.take(10).toList()}');

        setState(() {
          _countries = countries;
          _mainDestination = defaultCountry;
        });

        print('国リスト設定完了。総数: ${_countries.length}');
      } else {
        print('APIエラー: ${response.statusCode}');
        _setFallbackCountries();
      }
    } catch (e, stackTrace) {
      print('国のリスト取得エラー: $e');
      print('スタックトレース: $stackTrace');
      _setFallbackCountries();
    }
    print('=== 国リスト取得終了 ===');
  }

  void _setFallbackCountries() {
    print('フォールバック国リストを設定');
    setState(() {
      if (_userLanguage == 'ja') {
        _countries = [
          '日本', 'アメリカ合衆国', '大韓民国', '中華人民共和国', 'イギリス', 'フランス',
          'ドイツ', 'イタリア', 'スペイン', 'オーストラリア', 'カナダ',
          'ブラジル', 'インド', 'タイ', 'シンガポール', 'マレーシア',
          'インドネシア', 'フィリピン', 'ベトナム', 'メキシコ'
        ];
        _mainDestination = '日本';
      } else {
        _countries = [
          'Japan', 'United States', 'South Korea', 'China', 'United Kingdom', 'France',
          'Germany', 'Italy', 'Spain', 'Australia', 'Canada',
          'Brazil', 'India', 'Thailand', 'Singapore', 'Malaysia',
          'Indonesia', 'Philippines', 'Vietnam', 'Mexico'
        ];
        _mainDestination = 'Japan';
      }
    });
    print('フォールバック国リスト設定完了: ${_countries.length}カ国');
  }

  // 国選択のドラムロール表示
  void _showCountryPicker() {
    print('=== 国選択ピッカー表示 ===');
    print('現在の国リスト数: ${_countries.length}');
    print('現在選択中の国: $_mainDestination');

    int selectedIndex = _countries.indexOf(_mainDestination);
    if (selectedIndex == -1) {
      selectedIndex = 0;
      print('選択中の国が見つからないため、インデックス0を使用');
    } else {
      print('選択中の国のインデックス: $selectedIndex');
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        print('ModalBottomSheet構築中');
        return Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _userLanguage == 'ja' ? '国を選択' : 'Select Country',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${_userLanguage == 'ja' ? '利用可能な国数' : 'Available countries'}: ${_countries.length}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _countries.isEmpty
                    ? Center(
                  child: Text(
                    _userLanguage == 'ja' ? '国リストが読み込まれていません' : 'Country list not loaded',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
                    : ListWheelScrollView.useDelegate(
                  itemExtent: 50,
                  controller: FixedExtentScrollController(initialItem: selectedIndex),
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    selectedIndex = index;
                    print('選択された国インデックス: $index (${_countries[index]})');
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      if (index < 0 || index >= _countries.length) return null;
                      return Container(
                        alignment: Alignment.center,
                        child: Text(
                          _countries[index],
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    },
                    childCount: _countries.length,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        print('キャンセルボタン押下');
                        Navigator.pop(context);
                      },
                      child: Text(
                        _getLocalizedText('cancel'),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_countries.isNotEmpty && selectedIndex < _countries.length) {
                          print('選択ボタン押下: ${_countries[selectedIndex]}');
                          setState(() {
                            _mainDestination = _countries[selectedIndex];
                          });
                          Navigator.pop(context);
                        } else {
                          print('無効な選択: selectedIndex=$selectedIndex, countries.length=${_countries.length}');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _userLanguage == 'ja' ? '選択' : 'Select',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 画像選択
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  // 日付選択
  Future<void> _selectDate(BuildContext context, bool isDeparture) async {
    // 言語設定が読み込まれるまで待機
    if (!_isLanguageLoaded) {
      await _loadUserLanguage();
    }

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.teal.shade50,
                  Colors.white,
                  Colors.blue.shade50,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade400, Colors.teal.shade600],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDeparture ? Icons.flight_takeoff : Icons.flight_land,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isDeparture
                            ? _getLocalizedText('selectDepartureDate')
                            : _getLocalizedText('selectReturnDate'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      // カレンダーの言語設定を適用
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: Colors.teal,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Colors.black87,
                      ),
                    ),
                    child: Localizations(
                      locale: Locale(_userLanguage),
                      delegates: const [
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                      ],
                      child: CalendarDatePicker(
                        initialDate: isDeparture
                            ? (_departureDate ?? DateTime.now())
                            : (_returnDate ?? DateTime.now()),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        onDateChanged: (DateTime date) {
                          Navigator.pop(context, date);
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Text(
                            _getLocalizedText('cancel'),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, isDeparture
                                ? (_departureDate ?? DateTime.now())
                                : (_returnDate ?? DateTime.now()));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 3,
                          ),
                          child: Text(
                            _getLocalizedText('confirm'),
                            style: const TextStyle(
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
              ],
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isDeparture) {
          _departureDate = picked;
        } else {
          _returnDate = picked;
        }
      });
    }
  }

  // デバッグ出力
  void _debugPrint() {
    print('=== しおり情報 デバッグ ===');
    print('タイトル: ${_titleController.text}');
    print('出発日: ${_departureDate?.toString() ?? "未設定"}');
    print('帰宅日: ${_returnDate?.toString() ?? "未設定"}');
    print('主な渡航先: $_mainDestination');
    print('利用可能国数: ${_countries.length}');
    print('最初の10カ国: ${_countries.take(10).toList()}');
    print('その他の渡航先: ${_otherDestinationController.text}');
    print('画像: ${_selectedImage?.path ?? "未選択"}');
    print('ロック状態: $_isLocked');
    print('チャット送信無効: $_isChatDisabled');
    print('ユーザー言語: $_userLanguage');
    print('========================');
  }

  // しおり作成
  void _createShiori() {
    _debugPrint();

    // 作成処理をここに実装
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_userLanguage == 'ja' ? 'しおりを作成しました！' : 'Shiori created successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 言語設定が読み込まれていない場合はローディング表示
    if (!_isLanguageLoaded) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Loading...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 56,
        leading: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        title: Text(
          _userLanguage == 'ja' ? '新規しおり作成' : 'Create New Shiori',
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // しおりタイトル
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: _userLanguage == 'ja' ? 'しおりのタイトルを入力' : 'Enter shiori title',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade400, Colors.purple.shade600],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 出発日
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade400, Colors.teal.shade600],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 20),
                ),
                title: Text(
                  _getLocalizedText('departureDate'),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _departureDate == null
                      ? _getLocalizedText('selectDate')
                      : _formatDate(_departureDate!),
                  style: TextStyle(
                    color: _departureDate == null ? Colors.grey : Colors.teal.shade700,
                    fontSize: 13,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.calendar_today, color: Colors.teal.shade600, size: 20),
                ),
                onTap: () => _selectDate(context, true),
              ),
            ),
            const SizedBox(height: 16),

            // 帰宅日
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flight_land, color: Colors.white, size: 20),
                ),
                title: Text(
                  _getLocalizedText('returnDate'),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _returnDate == null
                      ? _getLocalizedText('selectDate')
                      : _formatDate(_returnDate!),
                  style: TextStyle(
                    color: _returnDate == null ? Colors.grey : Colors.blue.shade700,
                    fontSize: 13,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.calendar_today, color: Colors.blue.shade600, size: 20),
                ),
                onTap: () => _selectDate(context, false),
              ),
            ),
            const SizedBox(height: 24),

            // 主な渡航先
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(
                  _userLanguage == 'ja' ? '主な渡航先' : 'Main Destination',
                  style: const TextStyle(color: Colors.black),
                ),
                subtitle: Text(
                  '${_userLanguage == 'ja' ? '利用可能' : 'Available'}: ${_countries.length}${_userLanguage == 'ja' ? 'カ国' : ' countries'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _mainDestination,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  ],
                ),
                onTap: () {
                  print('主な渡航先タップ - 国数: ${_countries.length}');
                  _showCountryPicker();
                },
              ),
            ),
            const SizedBox(height: 16),

            // その他の渡航先を追加
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _otherDestinationController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: _userLanguage == 'ja' ? 'その他の渡航先を追加' : 'Add other destinations',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 画像セクション
            Text(
              _userLanguage == 'ja' ? '画像' : 'Image',
              style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // しおり画像を変更
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: Text(
                        _userLanguage == 'ja' ? 'しおり画像を変更' : 'Change shiori image',
                        style: const TextStyle(color: Colors.black),
                      ),
                      onTap: _pickImage,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                      : const Icon(
                    Icons.add,
                    color: Colors.grey,
                    size: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // しおりをロック
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                title: Text(
                  _userLanguage == 'ja' ? 'しおりをロック' : 'Lock shiori',
                  style: const TextStyle(color: Colors.black),
                ),
                subtitle: Text(
                  _userLanguage == 'ja'
                      ? 'ロックするとあなただけがそのしおりを編集できます。ただし、メンバーが自分で作った項目はそのメンバーも編集できます。'
                      : 'When locked, only you can edit this shiori. However, members can still edit items they created.',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                value: _isLocked,
                onChanged: (bool value) {
                  setState(() {
                    _isLocked = value;
                  });
                },
                activeColor: Colors.white,
                activeTrackColor: Colors.teal,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 16),

            // チャット送信させない
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                title: Text(
                  _userLanguage == 'ja' ? 'チャット送信させない' : 'Disable chat sending',
                  style: const TextStyle(color: Colors.black),
                ),
                subtitle: Text(
                  _userLanguage == 'ja'
                      ? 'しおりの編集を行うとメンバー全員の位置共有が一度無効となります。再度個別にONにしてください。'
                      : 'Editing the shiori will temporarily disable location sharing for all members. Please turn it back on individually.',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                value: _isChatDisabled,
                onChanged: (bool value) {
                  setState(() {
                    _isChatDisabled = value;
                  });
                },
                activeColor: Colors.white,
                activeTrackColor: Colors.teal,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 32),

            // 作成ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createShiori,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  _userLanguage == 'ja' ? '✓ 作成' : '✓ Create',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}