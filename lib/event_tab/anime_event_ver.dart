import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:parts/spot_page/parts/event_calendar_selector.dart';
// Import the new EventSection widget
import 'event_section.dart';

class NewtAppUI extends StatefulWidget {
  // カスタマイズ可能なプロパティを追加
  final double buttonHeight;
  final double buttonWidth;
  final double buttonBorderRadius;

  const NewtAppUI({
    Key? key,
    this.buttonHeight = 40,  // デフォルト値として60を設定
    this.buttonWidth = double.infinity,  // デフォルト値としてdouble.infinityを設定
    this.buttonBorderRadius = 30,  // デフォルト値として30を設定
  }) : super(key: key);

  @override
  State<NewtAppUI> createState() => _NewtAppUIState();
}

class _NewtAppUIState extends State<NewtAppUI> {
  // 選択中のタブを追跡する変数（0: イベント, 1: グッズ）
  int _selectedTabIndex = 0;
  // アニメ入力用のコントローラ
  final TextEditingController _animeController = TextEditingController();
  final TextEditingController _goodsAnimeController = TextEditingController();
  // 選択された都道府県（複数選択対応）
  Set<String> _selectedPrefectures = {};
  // 開催期間の日付範囲
  DateTime? _startDate;
  DateTime? _endDate;

  // 表示用の都道府県テキスト
  String get _selectedPrefectureText {
    if (_selectedPrefectures.isEmpty) {
      return '都道府県をえらぶ';
    } else if (_selectedPrefectures.length == 1) {
      return _selectedPrefectures.first;
    } else {
      return '${_selectedPrefectures.first} 他${_selectedPrefectures.length - 1}件';
    }
  }

  // 開催期間のテキスト表示用
  String get _dateRangeText {
    if (_startDate == null) {
      return '開催期間をえらぶ';
    } else if (_endDate == null) {
      return DateFormat('yyyy/MM/dd').format(_startDate!);
    } else {
      return '${DateFormat('yyyy/MM/dd').format(_startDate!)} - ${DateFormat('yyyy/MM/dd').format(_endDate!)}';
    }
  }

  // 展開された地方を追跡
  Map<String, bool> _expandedRegions = {
    '北海道・東北地方': false,
    '関東地方': false,
    '中部地方': false,
    '近畿地方': false,
    '中国・四国地方': false,
    '九州・沖縄地方': false,
  };

  // 地方ごとの都道府県リスト
  final Map<String, List<String>> _prefecturesByRegion = {
    '北海道・東北地方': ['北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県'],
    '関東地方': ['茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県'],
    '中部地方': ['新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県', '岐阜県', '静岡県', '愛知県'],
    '近畿地方': ['三重県', '滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県'],
    '中国・四国地方': ['鳥取県', '島根県', '岡山県', '広島県', '山口県', '徳島県', '香川県', '愛媛県', '高知県'],
    '九州・沖縄地方': ['福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県'],
  };

  @override
  void dispose() {
    _animeController.dispose();
    _goodsAnimeController.dispose();
    super.dispose();
  }

  // カレンダー選択画面を表示
  void _showCalendarSelector() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventCalendarSelector(
          onDateRangeSelected: (start, end) {
            setState(() {
              _startDate = start;
              _endDate = end;
            });
          },
        ),
      ),
    );
  }

  // 都道府県選択用のボトムシートを表示
  void _showPrefectureSelector() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 高さを調整可能にする
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.66, // 画面の2/3の高さで表示
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return _buildPrefectureSheet(scrollController, setModalState);
              },
            );
          },
        );
      },
    );
  }

  // 都道府県選択用のボトムシートの内容
  Widget _buildPrefectureSheet(ScrollController scrollController, StateSetter setModalState) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: const Text(
            '目的地',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '📍エリアからさがす',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // 全ての地方を表示
                for (String region in _prefecturesByRegion.keys)
                  _expandedRegions[region]!
                      ? _buildExpandedRegionSection(region, setModalState)
                      : _buildRegionSection(region, setModalState),

                const SizedBox(height: 80), // ボタン用のスペース
              ],
            ),
          ),
        ),
        // 下部の固定ボタン
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _selectedPrefectures.clear();
                    });
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    side: BorderSide(color: Colors.grey),
                  ),
                  child: const Text('クリア'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00bfff),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('決定する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 地域セクションを構築（閉じた状態）
  Widget _buildRegionSection(String title, StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            setModalState(() {
              _expandedRegions[title] = true;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
        Divider(height: 1),
      ],
    );
  }

  // 展開された地域セクションを構築
  Widget _buildExpandedRegionSection(String title, StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            setModalState(() {
              _expandedRegions[title] = false;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
        ),
        Divider(height: 1),

        // 選択可能なすべての都道府県を表示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildSelectionChip('すべて', setModalState,
                  isSelected: _prefecturesByRegion[title]!.every((prefecture) => _selectedPrefectures.contains(prefecture))),
              ..._prefecturesByRegion[title]!.map((prefecture) =>
                  _buildSelectionChip(prefecture, setModalState,
                      isSelected: _selectedPrefectures.contains(prefecture))
              ).toList(),
            ],
          ),
        ),

        Divider(height: 24),
      ],
    );
  }

  // 選択チップを構築（複数選択対応）
  Widget _buildSelectionChip(String label, StateSetter setModalState, {bool isSelected = false}) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF00bfff).withOpacity(0.2),
      side: BorderSide(
        color: isSelected ? const Color(0xFF00bfff) : Colors.grey[300]!,
      ),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF00bfff) : Colors.black,
      ),
      onSelected: (bool selected) {
        HapticFeedback.mediumImpact();
        setModalState(() {
          setState(() {
            if (label == 'すべて') {
              // すべて選択の場合、その地方の全都道府県を選択/解除
              String currentRegion = _prefecturesByRegion.keys.firstWhere(
                    (region) => _expandedRegions[region]! == true,
                orElse: () => '',
              );

              if (currentRegion.isNotEmpty) {
                if (selected) {
                  // すべての都道府県を追加
                  _selectedPrefectures.addAll(_prefecturesByRegion[currentRegion]!);
                } else {
                  // その地方の都道府県をすべて削除
                  _selectedPrefectures.removeWhere((prefecture) =>
                      _prefecturesByRegion[currentRegion]!.contains(prefecture));
                }
              }
            } else {
              // 個別の都道府県選択
              if (selected) {
                _selectedPrefectures.add(label);
              } else {
                _selectedPrefectures.remove(label);
              }
            }
          });
        });
      },
      shape: StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      showCheckmark: true,
      checkmarkColor: const Color(0xFF00bfff),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 20.0,
            ),
            // Main menu tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // イベントタブ
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // 触覚フィードバックを追加
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _selectedTabIndex = 0;
                        });
                      },
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event,
                                  color: _selectedTabIndex == 0
                                      ? const Color(0xFF00bfff)
                                      : Colors.grey,
                                  size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'イベント',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTabIndex == 0
                                      ? const Color(0xFF00bfff)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 4,
                            color: _selectedTabIndex == 0
                                ? const Color(0xFF00bfff)
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // グッズタブ
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // 触覚フィードバックを追加
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _selectedTabIndex = 1;
                        });
                      },
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.card_giftcard,
                                  color: _selectedTabIndex == 1
                                      ? const Color(0xFF00bfff)
                                      : Colors.grey,
                                  size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'グッズ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTabIndex == 1
                                      ? const Color(0xFF00bfff)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 4,
                            color: _selectedTabIndex == 1
                                ? const Color(0xFF00bfff)
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // タブに応じたコンテンツを表示
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildEventContent()
                  : _buildGoodsContent(),
            ),
          ],
        ),
      ),
    );
  }

  // イベントのコンテンツ
  Widget _buildEventContent() {
    return SingleChildScrollView(  // Added ScrollView to handle overflow when content expands
      child: Column(
        children: [
          // 検索フォームフィールド
          Column(
            children: [
              // アニメ選択 - テキスト入力フィールドに変更
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _animeController,
                  decoration: InputDecoration(
                    icon: Icon(Icons.movie_creation_outlined),
                    hintText: 'アニメを入力',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const Divider(height: 1),

              // 都道府県選択 - ボトムシート表示用に変更
              InkWell(
                onTap: _showPrefectureSelector,
                child: ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(_selectedPrefectureText),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  minLeadingWidth: 20,
                ),
              ),
              const Divider(height: 1),

              // 開催期間選択 - カレンダー選択画面表示用に変更
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(_dateRangeText),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                minLeadingWidth: 20,
                onTap: _showCalendarSelector,
              ),
              const Divider(height: 1),
            ],
          ),

          // 検索ボタン
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00bfff),
                foregroundColor: Colors.white,
                minimumSize: Size(widget.buttonWidth, widget.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(widget.buttonBorderRadius),
                ),
              ),
              child: const Text(
                'イベントをさがす',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // ここに EventSectionを追加
          const EventSection(),
        ],
      ),
    );
  }

  // グッズのコンテンツ
  Widget _buildGoodsContent() {
    return Column(
      children: [
        // 検索フォームフィールド
        Column(
          children: [
            // アニメ選択のみ - テキスト入力フィールド
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _goodsAnimeController,
                decoration: InputDecoration(
                  icon: Icon(Icons.movie_creation_outlined),
                  hintText: 'アニメを入力',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const Divider(height: 1),
          ],
        ),

        // 検索ボタン
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00bfff),
              foregroundColor: Colors.white,
              minimumSize: Size(widget.buttonWidth, widget.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.buttonBorderRadius),
              ),
            ),
            child: const Text(
              'グッズをさがす',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}