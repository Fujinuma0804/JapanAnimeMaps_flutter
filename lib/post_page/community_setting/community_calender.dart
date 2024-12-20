import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class EventsScreen extends StatefulWidget {
  final String communityId;

  const EventsScreen({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  final List<String> weekDays = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  String _formatMonthYear(DateTime date) {
    return '${date.year}年${date.month}月';
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _events[normalizedDate] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'カレンダー',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('community_list')
            .doc(widget.communityId)
            .collection('events')
            .orderBy('date')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました'));
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data!.docs;

          // イベントマップの更新
          _events = {};
          for (var event in events) {
            final data = event.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            final dateOnly = DateTime(date.year, date.month, date.day);

            if (!_events.containsKey(dateOnly)) {
              _events[dateOnly] = [];
            }
            _events[dateOnly]!.add(event);
          }

          return Column(
            children: [
              Card(
                margin: EdgeInsets.all(8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  eventLoader: _getEventsForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  daysOfWeekHeight: 32,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                    titleTextFormatter: (date, locale) =>
                        _formatMonthYear(date),
                  ),
                  calendarStyle: CalendarStyle(
                    markerDecoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Color(0xFF00008b),
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 1,
                    markerSize: 6,
                    markerMargin: const EdgeInsets.only(top: 4),
                  ),
                  calendarBuilders: CalendarBuilders(
                    dowBuilder: (context, day) {
                      final index = day.weekday - 1; // 1-7 -> 0-6
                      final weekDays = ['月', '火', '水', '木', '金', '土', '日'];

                      Color textColor;
                      if (day.weekday == DateTime.saturday) {
                        textColor = Colors.blue; // 土曜日は水色
                      } else if (day.weekday == DateTime.sunday) {
                        textColor = Colors.red; // 日曜日は赤色
                      } else {
                        textColor = Colors.black87; // 平日は黒
                      }

                      return Center(
                        child: Text(
                          weekDays[index],
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                    defaultBuilder: (context, day, focusedDay) {
                      Color textColor;
                      if (day.weekday == DateTime.saturday) {
                        textColor = Colors.blue;
                      } else if (day.weekday == DateTime.sunday) {
                        textColor = Colors.red;
                      } else {
                        textColor = Colors.black87;
                      }

                      return Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(color: textColor),
                        ),
                      );
                    },
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
              ),
              if (events.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '予定はありません',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'チャットで /YYYYMMDD を入力して\n予定を追加できます\n予定についてはメンバー全員に公開されます。',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final data = event.data() as Map<String, dynamic>;
                      final date = (data['date'] as Timestamp).toDate();

                      if (_selectedDay != null &&
                          !isSameDay(date, _selectedDay)) {
                        return SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          if (index == 0 ||
                              !isSameDay(
                                  (events[index - 1].data()
                                          as Map<String, dynamic>)['date']
                                      .toDate(),
                                  date))
                            _buildDateHeader(date),
                          SizedBox(height: 8),
                          _buildEventCard(event),
                          SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));

    String dateText;
    if (isSameDay(date, today)) {
      dateText = '今日';
    } else if (isSameDay(date, tomorrow)) {
      dateText = '明日';
    } else {
      dateText = '${date.month}月${date.day}日';
      if (date.year != today.year) {
        dateText = '${date.year}年$dateText';
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 16, color: Colors.blue),
          SizedBox(width: 8),
          Text(
            dateText,
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot event) {
    final data = event.data() as Map<String, dynamic>;
    final date = (data['date'] as Timestamp).toDate();
    final createdAt = (data['createdAt'] as Timestamp).toDate();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // タップ時の処理（詳細表示など）
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.event,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_formatTime(date)}',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '作成: ${_formatDateTime(createdAt)}',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.month}/${date.day} ${_formatTime(date)}';
  }
}
