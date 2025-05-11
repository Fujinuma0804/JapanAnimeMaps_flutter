import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// カレンダー選択のためのウィジェット
class EventCalendarSelector extends StatefulWidget {
  final Function(DateTime?, DateTime?) onDateRangeSelected;

  const EventCalendarSelector({
    Key? key,
    required this.onDateRangeSelected,
  }) : super(key: key);

  @override
  State<EventCalendarSelector> createState() => _EventCalendarSelectorState();
}

class _EventCalendarSelectorState extends State<EventCalendarSelector> {
  // 現在表示中の年月
  DateTime _currentMonth = DateTime.now();
  // 翌月
  late DateTime _nextMonth;
  // 翌々月
  late DateTime _thirdMonth;
  // 3ヶ月後
  late DateTime _fourthMonth;
  // 選択された範囲
  DateTime? _startDate;
  DateTime? _endDate;
  // 日付範囲の柔軟性
  String _selectedFlexibility = '指定日のみ'; // デフォルト選択

  @override
  void initState() {
    super.initState();
    _nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    _thirdMonth = DateTime(_currentMonth.year, _currentMonth.month + 2, 1);
    _fourthMonth = DateTime(_currentMonth.year, _currentMonth.month + 3, 1);
  }

  // 日付範囲の柔軟性オプション
  final List<String> _flexibilityOptions = ['指定日のみ', '±1日', '±2日', '±3日', '±7日'];

  // 指定された月のカレンダーグリッドを構築
  Widget _buildCalendarGrid(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    // 日本語の曜日配列（日曜始まり）
    final weekdays = ['日', '月', '火', '水', '木', '金', '土'];

    // 曜日行を構築
    final weekdayRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: weekdays.map((day) {
        Color textColor = Colors.black;
        if (day == '日') textColor = Colors.red;
        if (day == '土') textColor = Colors.blue;

        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );

    // カレンダーグリッドの開始位置（月の最初の日の曜日）
    final firstWeekday = firstDayOfMonth.weekday % 7;

    // 総日数の計算（前月の残り + 当月の日数）
    final totalDays = firstWeekday + lastDayOfMonth.day;

    // 必要な週の数
    final weeksCount = (totalDays / 7).ceil();

    // カレンダーグリッドを構築
    List<Widget> calendarRows = [];

    int dayCounter = 1 - firstWeekday;

    for (int week = 0; week < weeksCount; week++) {
      List<Widget> weekChildren = [];

      for (int i = 0; i < 7; i++) {
        if (dayCounter < 1 || dayCounter > lastDayOfMonth.day) {
          // 前月または翌月の日はグレーアウト
          weekChildren.add(Expanded(child: Center(child: Text(''))));
        } else {
          final currentDate = DateTime(month.year, month.month, dayCounter);
          final now = DateTime.now();
          final isToday = currentDate.year == now.year &&
              currentDate.month == now.month &&
              currentDate.day == now.day;

          final isPast = currentDate.isBefore(DateTime(now.year, now.month, now.day));

          // 選択状態の確認
          bool isSelected = false;
          bool isInRange = false;

          if (_startDate != null && _endDate != null) {
            isInRange = currentDate.isAfter(_startDate!) &&
                currentDate.isBefore(_endDate!);
            isSelected = isSameDay(currentDate, _startDate!) ||
                isSameDay(currentDate, _endDate!);
          } else if (_startDate != null) {
            isSelected = isSameDay(currentDate, _startDate!);
          }

          // 曜日による色分け
          Color textColor = Colors.black;
          if (i == 0) textColor = Colors.red;  // 日曜
          if (i == 6) textColor = Colors.blue; // 土曜

          if (isPast) {
            // 過去の日付はグレーアウト
            weekChildren.add(
              Expanded(
                child: Center(
                  child: Text(
                    dayCounter.toString(),
                    style: TextStyle(
                      color: Colors.grey[300],
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ),
            );
          } else {
            // 選択可能な日付
            Color backgroundColor = Colors.transparent;
            Color borderColor = Colors.transparent;

            if (isSelected) {
              backgroundColor = const Color(0xFFFFF9C4); // 選択された日付は黄色
              borderColor = const Color(0xFF00bfff); // 緑色の境界線
            } else if (isInRange) {
              backgroundColor = const Color(0xFFE8F5E9); // 範囲内は薄緑
            }

            if (_startDate != null && isSameDay(currentDate, _startDate!)) {
              if (i == 0 && isSelected) {
                // 開始日が日曜日で選択されている場合
                backgroundColor = const Color(0xFFFFF9C4);
              }
            }

            if (_startDate != null && _endDate != null) {
              if (isSameDay(currentDate, _startDate!)) {
                backgroundColor = const Color(0xFFFFF9C4);
              } else if (isSameDay(currentDate, _endDate!)) {
                backgroundColor = const Color(0xFFFFF9C4);
              }
            }

            if (isToday && !isSelected && !isInRange) {
              borderColor = Color(0xFF00bfff);
            }

            final dayWidget = GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _selectDate(currentDate);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                  border: borderColor != Colors.transparent
                      ? Border.all(color: borderColor, width: 2)
                      : null,
                ),
                width: 40,
                height: 40,
                child: Center(
                  child: Text(
                    dayCounter.toString(),
                    style: TextStyle(
                      color: isPast ? Colors.grey : textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );

            weekChildren.add(Expanded(child: Center(child: dayWidget)));
          }
        }

        dayCounter++;
      }

      calendarRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: weekChildren,
          ),
        ),
      );
    }

    return Column(
      children: [
        weekdayRow,
        const SizedBox(height: 8),
        ...calendarRows,
      ],
    );
  }

  // 日付が同じかどうかを確認する関数
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // 日付選択の処理
  void _selectDate(DateTime date) {
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        // 新しい選択範囲の開始
        _startDate = date;
        _endDate = null;
      } else {
        // 既に開始日が選択されている場合
        if (date.isBefore(_startDate!)) {
          // 選択された日付が現在の開始日より前の場合
          _endDate = _startDate;
          _startDate = date;
        } else {
          _endDate = date;
        }
      }

      // 親ウィジェットに選択結果を通知
      widget.onDateRangeSelected(_startDate, _endDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 月の表示用フォーマット
    final DateFormat monthFormat = DateFormat('yyyy年M月', 'ja_JP');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '参加希望日期間',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),

          // カレンダー部分
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 現在の月のカレンダー
                    Text(
                      monthFormat.format(_currentMonth),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCalendarGrid(_currentMonth),
                    const SizedBox(height: 32),

                    // 翌月のカレンダー
                    Text(
                      monthFormat.format(_nextMonth),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCalendarGrid(_nextMonth),
                    const SizedBox(height: 32),

                    // 翌々月のカレンダー
                    Text(
                      monthFormat.format(_thirdMonth),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCalendarGrid(_thirdMonth),
                    const SizedBox(height: 32),

                    // 3ヶ月後のカレンダー
                    Text(
                      monthFormat.format(_fourthMonth),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCalendarGrid(_fourthMonth),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // 下部の選択オプション
          Column(
            children: [
              const Divider(height: 1),
              // 柔軟性オプションのセグメントコントロール
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _flexibilityOptions.map((option) {
                      final isSelected = _selectedFlexibility == option;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _selectedFlexibility = option;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? Color(0xFF00bfff) : Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(32),
                              color: isSelected ? Colors.white : Colors.white,
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                color: isSelected ? Color(0xFF00bfff) : Colors.grey[600],
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 提示テキスト
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '参加を希望する期間をえらんでください',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.flight, size: 18, color: Colors.grey[600]),
                  ],
                ),
              ),

              // 下部のボタン
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // 日付未定ボタン
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                          widget.onDateRangeSelected(null, null);
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          '日付未定',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 決定ボタン
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: _startDate != null ? () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF00bfff),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: const Text(
                          '決定する',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 20.0,
              ),
            ],
          ),
        ],
      ),
    );
  }
}