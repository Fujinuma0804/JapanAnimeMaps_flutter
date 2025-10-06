import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parts/shiori/shiori_bottom_member.dart';

class DestinationItem {
  final String placeId;
  final String name;
  final String description;
  final String? photoReference;
  final String? imageUrl;
  final IconData? icon;

  DestinationItem({
    required this.placeId,
    required this.name,
    required this.description,
    this.photoReference,
    this.imageUrl,
    this.icon,
  });

  factory DestinationItem.fromJson(Map<String, dynamic> json) {
    String? photoRef;
    if (json['photos'] != null && json['photos'].isNotEmpty) {
      photoRef = json['photos'][0]['photo_reference'];
    }

    return DestinationItem(
      placeId: json['place_id'] ?? '',
      name: json['description'] ??
          json['structured_formatting']?['main_text'] ??
          '',
      description: json['structured_formatting']?['secondary_text'] ?? '場所',
      photoReference: photoRef,
    );
  }
}

class DestinationSearchScreen extends StatefulWidget {
  final Function(String) onDestinationSelected;

  const DestinationSearchScreen({
    Key? key,
    required this.onDestinationSelected,
  }) : super(key: key);

  @override
  State<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DestinationItem> _filteredDestinations = [];
  bool _isLoading = false;

  // Google Places APIキー
  static const String _apiKey = 'AIzaSyCotKIa2a4mjj3FOeF5gy04iGUhsxHHJrY';

  // 都道府県リスト
  static const Map<String, String> _prefectures = {
    '北海道': 'Hokkaido',
    '青森': 'Aomori',
    '青森県': 'Aomori',
    '岩手': 'Iwate',
    '岩手県': 'Iwate',
    '宮城': 'Miyagi',
    '宮城県': 'Miyagi',
    '秋田': 'Akita',
    '秋田県': 'Akita',
    '山形': 'Yamagata',
    '山形県': 'Yamagata',
    '福島': 'Fukushima',
    '福島県': 'Fukushima',
    '茨城': 'Ibaraki',
    '茨城県': 'Ibaraki',
    '栃木': 'Tochigi',
    '栃木県': 'Tochigi',
    '群馬': 'Gunma',
    '群馬県': 'Gunma',
    '埼玉': 'Saitama',
    '埼玉県': 'Saitama',
    '千葉': 'Chiba',
    '千葉県': 'Chiba',
    '東京': 'Tokyo',
    '東京都': 'Tokyo',
    '神奈川': 'Kanagawa',
    '神奈川県': 'Kanagawa',
    '新潟': 'Niigata',
    '新潟県': 'Niigata',
    '富山': 'Toyama',
    '富山県': 'Toyama',
    '石川': 'Ishikawa',
    '石川県': 'Ishikawa',
    '福井': 'Fukui',
    '福井県': 'Fukui',
    '山梨': 'Yamanashi',
    '山梨県': 'Yamanashi',
    '長野': 'Nagano',
    '長野県': 'Nagano',
    '岐阜': 'Gifu',
    '岐阜県': 'Gifu',
    '静岡': 'Shizuoka',
    '静岡県': 'Shizuoka',
    '愛知': 'Aichi',
    '愛知県': 'Aichi',
    '三重': 'Mie',
    '三重県': 'Mie',
    '滋賀': 'Shiga',
    '滋賀県': 'Shiga',
    '京都': 'Kyoto',
    '京都府': 'Kyoto',
    '大阪': 'Osaka',
    '大阪府': 'Osaka',
    '兵庫': 'Hyogo',
    '兵庫県': 'Hyogo',
    '奈良': 'Nara',
    '奈良県': 'Nara',
    '和歌山': 'Wakayama',
    '和歌山県': 'Wakayama',
    '鳥取': 'Tottori',
    '鳥取県': 'Tottori',
    '島根': 'Shimane',
    '島根県': 'Shimane',
    '岡山': 'Okayama',
    '岡山県': 'Okayama',
    '広島': 'Hiroshima',
    '広島県': 'Hiroshima',
    '山口': 'Yamaguchi',
    '山口県': 'Yamaguchi',
    '徳島': 'Tokushima',
    '徳島県': 'Tokushima',
    '香川': 'Kagawa',
    '香川県': 'Kagawa',
    '愛媛': 'Ehime',
    '愛媛県': 'Ehime',
    '高知': 'Kochi',
    '高知県': 'Kochi',
    '福岡': 'Fukuoka',
    '福岡県': 'Fukuoka',
    '佐賀': 'Saga',
    '佐賀県': 'Saga',
    '長崎': 'Nagasaki',
    '長崎県': 'Nagasaki',
    '熊本': 'Kumamoto',
    '熊本県': 'Kumamoto',
    '大分': 'Oita',
    '大分県': 'Oita',
    '宮崎': 'Miyazaki',
    '宮崎県': 'Miyazaki',
    '鹿児島': 'Kagoshima',
    '鹿児島県': 'Kagoshima',
    '沖縄': 'Okinawa',
    '沖縄県': 'Okinawa',
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // 初期表示で神奈川の結果を表示
    _searchController.text = '';
    _searchPlaces('');
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isNotEmpty) {
      _searchPlaces(query);
    } else {
      setState(() {
        _filteredDestinations = [];
      });
    }
  }

  bool _isPrefecture(String query) {
    return _prefectures.containsKey(query);
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      List<DestinationItem> destinations = [];

      // 都道府県かチェック
      if (_isPrefecture(query)) {
        // 都道府県の場合は市区町村を検索
        destinations = await _searchCitiesInPrefecture(query);
      } else {
        // 通常の地名検索
        destinations = await _searchGeneralPlaces(query);
      }

      setState(() {
        _filteredDestinations = destinations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching places: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<DestinationItem>> _searchCitiesInPrefecture(
      String prefecture) async {
    List<DestinationItem> destinations = [];

    // 都道府県内の主要都市を検索
    final String url =
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
        '?query=${Uri.encodeComponent('$prefecture 市 町 村')}'
        '&type=locality'
        '&language=ja'
        '&region=jp'
        '&key=$_apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'] ?? [];

      for (var result in results.take(15)) {
        String? photoRef;
        if (result['photos'] != null && result['photos'].isNotEmpty) {
          photoRef = result['photos'][0]['photo_reference'];
        }

        String name = result['name'] ?? '';
        String address = result['formatted_address'] ?? '';

        // 都道府県名が含まれているかチェック
        if (address.contains(prefecture) || name.contains(prefecture)) {
          destinations.add(DestinationItem(
            placeId: result['place_id'] ?? '',
            name: '$name・$address',
            description: '${prefecture}の市区町村',
            photoReference: photoRef,
          ));
        }
      }
    }

    // Autocomplete APIでも追加検索
    final autocompleteDestinations =
    await _searchGeneralPlaces('$prefecture 市');
    destinations.addAll(autocompleteDestinations);

    // 重複を除去
    final uniqueDestinations = <String, DestinationItem>{};
    for (var dest in destinations) {
      if (!uniqueDestinations.containsKey(dest.placeId)) {
        uniqueDestinations[dest.placeId] = dest;
      }
    }

    return uniqueDestinations.values.toList();
  }

  Future<List<DestinationItem>> _searchGeneralPlaces(String query) async {
    List<DestinationItem> destinations = [];

    // Google Places Autocomplete API
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&components=country:jp'
        '&language=ja'
        '&types=(cities)'
        '&key=$_apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> predictions = data['predictions'] ?? [];

      // 各予測結果に対して詳細情報を取得
      for (var prediction in predictions.take(10)) {
        final placeId = prediction['place_id'];
        final details = await _getPlaceDetails(placeId);

        if (details != null) {
          destinations.add(DestinationItem(
            placeId: placeId,
            name: prediction['description'] ?? '',
            description:
            prediction['structured_formatting']?['secondary_text'] ?? '場所',
            photoReference: details['photoReference'],
          ));
        }
      }
    }

    return destinations;
  }

  Future<Map<String, dynamic>?> _getPlaceDetails(String placeId) async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=photo'
          '&language=ja'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final result = data['result'];

        String? photoRef;
        if (result != null &&
            result['photos'] != null &&
            result['photos'].isNotEmpty) {
          photoRef = result['photos'][0]['photo_reference'];
        }

        return {
          'photoReference': photoRef,
        };
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
    return null;
  }

  String? _getPhotoUrl(String? photoReference) {
    if (photoReference == null) return null;
    return 'https://maps.googleapis.com/maps/api/place/photo'
        '?maxwidth=400'
        '&photoreference=$photoReference'
        '&key=$_apiKey';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '行き先',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '地方・都道府県・都市名など',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[500]),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // 自由文入力オプション
          if (_searchController.text.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                leading: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B9D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Abc',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _searchController.text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                subtitle: const Text(
                  '自由文入力　＊英数字記号、最大10文字',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  widget.onDestinationSelected(_searchController.text);
                  Navigator.of(context).pop();
                },
              ),
            ),

          // 検索結果リスト
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B9D),
              ),
            )
                : ListView.builder(
              itemCount: _filteredDestinations.length,
              itemBuilder: (context, index) {
                final destination = _filteredDestinations[index];
                final photoUrl = _getPhotoUrl(destination.photoReference);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: photoUrl != null
                          ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        loadingBuilder:
                            (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[300],
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.location_on,
                              color: Colors.grey[600],
                              size: 24,
                            ),
                          );
                        },
                      )
                          : Container(
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.location_on,
                          color: Colors.grey[600],
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    destination.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    destination.description,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    widget.onDestinationSelected(destination.name);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// おしゃれなカスタムカレンダーWidget
class StylishDateRangePicker extends StatefulWidget {
  final Function(DateTime?, DateTime?) onDateRangeSelected;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const StylishDateRangePicker({
    Key? key,
    required this.onDateRangeSelected,
    this.initialStartDate,
    this.initialEndDate,
  }) : super(key: key);

  @override
  State<StylishDateRangePicker> createState() => _StylishDateRangePickerState();
}

class _StylishDateRangePickerState extends State<StylishDateRangePicker> {
  DateTime _currentMonth = DateTime.now();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSelectingEnd = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    if (_startDate != null && _endDate == null) {
      _isSelectingEnd = true;
    }
  }

  List<String> get _monthNames => [
    '1月', '2月', '3月', '4月', '5月', '6月',
    '7月', '8月', '9月', '10月', '11月', '12月'
  ];

  List<String> get _weekDays => ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ハンドルバー
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ヘッダー
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '旅行日程を選択',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),

          // 選択状態の表示
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B9D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6B9D).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '出発日',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _startDate != null
                            ? '${_startDate!.month}月${_startDate!.day}日'
                            : '選択してください',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _startDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey[300],
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Text(
                          '帰着日',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          _endDate != null
                              ? '${_endDate!.month}月${_endDate!.day}日'
                              : '選択してください',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _endDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 月ナビゲーション
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month - 1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_left, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Text(
                  '${_currentMonth.year}年 ${_monthNames[_currentMonth.month - 1]}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month + 1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_right, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 曜日ヘッダー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: _weekDays.map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // カレンダーグリッド
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildCalendarGrid(),
            ),
          ),

          // ボタン
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _isSelectingEnd = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFFF6B9D)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'リセット',
                      style: TextStyle(
                        color: Color(0xFFFF6B9D),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_startDate != null && _endDate != null)
                        ? () {
                      widget.onDateRangeSelected(_startDate, _endDate);
                      Navigator.pop(context);
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B9D),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '決定',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final today = DateTime.now();

    List<Widget> dayWidgets = [];

    // 前月の空白日
    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    // 当月の日付
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isPast = date.isBefore(DateTime(today.year, today.month, today.day));
      final isSelected = (_startDate != null && _isSameDay(date, _startDate!)) ||
          (_endDate != null && _isSameDay(date, _endDate!));
      final isInRange = _isDateInRange(date);

      dayWidgets.add(
        GestureDetector(
          onTap: isPast ? null : () => _onDateTap(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _getDateColor(date, isSelected, isInRange, isPast),
              borderRadius: BorderRadius.circular(8),
              border: isToday
                  ? Border.all(color: const Color(0xFFFF6B9D), width: 2)
                  : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: _getTextColor(date, isSelected, isInRange, isPast),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      children: dayWidgets,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isDateInRange(DateTime date) {
    if (_startDate == null || _endDate == null) return false;
    return date.isAfter(_startDate!) && date.isBefore(_endDate!);
  }

  Color _getDateColor(DateTime date, bool isSelected, bool isInRange, bool isPast) {
    if (isPast) return Colors.transparent;
    if (isSelected) return const Color(0xFFFF6B9D);
    if (isInRange) return const Color(0xFFFF6B9D).withOpacity(0.3);
    return Colors.transparent;
  }

  Color _getTextColor(DateTime date, bool isSelected, bool isInRange, bool isPast) {
    if (isPast) return Colors.grey[300]!;
    if (isSelected) return Colors.white;
    if (isInRange) return const Color(0xFFFF6B9D);
    return Colors.black87;
  }

  void _onDateTap(DateTime date) {
    setState(() {
      if (_startDate == null || _isSelectingEnd) {
        if (_startDate == null) {
          _startDate = date;
          _isSelectingEnd = true;
        } else if (_endDate == null) {
          if (date.isAfter(_startDate!)) {
            _endDate = date;
            _isSelectingEnd = false;
          } else {
            _startDate = date;
            _endDate = null;
          }
        } else {
          _startDate = date;
          _endDate = null;
          _isSelectingEnd = true;
        }
      } else {
        _startDate = date;
        _endDate = null;
        _isSelectingEnd = true;
      }
    });
  }
}

class ShioriBottomWhere extends StatefulWidget {
  const ShioriBottomWhere({Key? key}) : super(key: key);

  @override
  State<ShioriBottomWhere> createState() => _ShioriBottomWhereState();
}

class _ShioriBottomWhereState extends State<ShioriBottomWhere> {
  String? selectedDestination;
  DateTime? departureDate;
  DateTime? returnDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '新規作成',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              // スキップ処理
            },
            child: const Text(
              'スキップ',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              '次の旅行について教えてください',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 40),

            // プログレスインジケーター
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            const Text(
              '概要',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 32),

            // 行き先セクション
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '行き先',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const Text(
                  '任意',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: () {
                // 行き先選択処理
                _showDestinationPicker();
              },
              child: Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  selectedDestination ?? 'タップして回答を選択',
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedDestination != null
                        ? Colors.black
                        : Colors.grey[400],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 出発日・帰着日セクション
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '出発日・帰着日',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const Text(
                  '任意',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: () {
                // カスタムカレンダーを表示
                _showStylishDatePicker();
              },
              child: Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getDateRangeText(),
                      style: TextStyle(
                        fontSize: 16,
                        color: (departureDate != null && returnDate != null)
                            ? Colors.black
                            : Colors.grey[400],
                      ),
                    ),
                    Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // 次へボタン
            Container(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ShioriBottomMember()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B9D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '次へ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDestinationPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DestinationSearchScreen(
          onDestinationSelected: (destination) {
            setState(() {
              selectedDestination = destination;
            });
          },
        ),
      ),
    );
  }

  void _showStylishDatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StylishDateRangePicker(
        initialStartDate: departureDate,
        initialEndDate: returnDate,
        onDateRangeSelected: (start, end) {
          setState(() {
            departureDate = start;
            returnDate = end;
          });
        },
      ),
    );
  }

  String _getDateRangeText() {
    if (departureDate != null && returnDate != null) {
      return '${_formatDate(departureDate!)} - ${_formatDate(returnDate!)}';
    }
    return '旅行日程はいつですか？';
  }

  String _formatDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }
}