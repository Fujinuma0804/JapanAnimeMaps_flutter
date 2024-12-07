import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:parts/post_page/timeline_screen.dart';
import 'package:table_calendar/table_calendar.dart';

class MenuScreen extends StatelessWidget {
  final String communityId;

  const MenuScreen({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  final List<MenuOption> gridMenuOptions = const [
    MenuOption(
      icon: Icons.people,
      title: 'メンバー',
      color: Colors.green,
    ),
    MenuOption(
      icon: Icons.person_add,
      title: '招待',
      color: Colors.orange,
    ),
    MenuOption(
      icon: Icons.event,
      title: 'カレンダー',
      color: Colors.blue,
    ),
    MenuOption(
      icon: Icons.exit_to_app,
      title: '退出',
      color: Colors.red,
    ),
  ];

  final List<MenuOption> listMenuOptions = const [
    MenuOption(
      icon: Icons.settings,
      title: '設定',
      color: Colors.grey,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'メニュー',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: gridMenuOptions.length,
                itemBuilder: (context, index) {
                  final option = gridMenuOptions[index];
                  return _buildGridItem(
                    context,
                    option,
                    () => _handleGridOptionTap(context, index),
                  );
                },
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                itemCount: listMenuOptions.length,
                itemBuilder: (context, index) {
                  final option = listMenuOptions[index];
                  return _buildListItem(
                    context,
                    option,
                    () => _handleListOptionTap(context, index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(
    BuildContext context,
    MenuOption option,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: option.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                option.icon,
                color: option.color,
                size: 32,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                option.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    MenuOption option,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: option.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  option.icon,
                  color: option.color,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Text(
                option.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Spacer(),
              Icon(
                Icons.chevron_right,
                color: Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleGridOptionTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        _handleMembers(context);
        break;
      case 1:
        _handleInvite(context);
        break;
      case 2:
        _handleEvents(context);
        break;
      case 3:
        _handleLeave(context);
        break;
    }
  }

  void _handleListOptionTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        _handleSettings(context);
        break;
    }
  }

  void _handleMembers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MembersScreen(communityId: communityId),
      ),
    );
  }

  void _handleInvite(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('招待'),
        content: Text('招待リンクを生成しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 招待リンク生成処理
            },
            child: Text('生成'),
          ),
        ],
      ),
    );
  }

  void _handleLeave(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ログインユーザーが見つかりません'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          '退出確認',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '本当に退出しますか？\n'
          '退出すると過去の履歴は削除されます。\n'
          'この操作は取り消せません。',
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(
              'キャンセル',
              style: TextStyle(color: Colors.grey),
            ),
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: Text(
              '退出する',
              style: TextStyle(color: Colors.red),
            ),
            isDestructiveAction: true,
            onPressed: () => _handleLeaveConfirmed(context, currentUser.uid),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLeaveConfirmed(
    BuildContext context,
    String userId,
  ) async {
    try {
      await _leaveCommunity(userId);

      Navigator.pop(context); // ダイアログを閉じる

      // TimelineScreenへ遷移
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => TimelineScreen()),
        (route) => false,
      );

      // 退出完了メッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            alignment: Alignment.center,
            height: 50,
            child: Text(
              'コミュニティを退出しました',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 2),
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      print('Error leaving community: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('退出処理に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _leaveCommunity(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('communities')
          .doc(communityId)
          .update({
        'isActive': false,
        'leftAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error leaving community: $e');
      throw e;
    }
  }

  void _handleSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(communityId: communityId),
      ),
    );
  }

  void _handleEvents(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventsScreen(communityId: communityId),
      ),
    );
  }
}

class MenuOption {
  final IconData icon;
  final String title;
  final Color color;

  const MenuOption({
    required this.icon,
    required this.title,
    required this.color,
  });
}

class MembersScreen extends StatelessWidget {
  final String communityId;

  const MembersScreen({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('メンバー'),
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF00008b),
        ),
        body: Center(child: Text('メンバー画面')),
      );
}

class SettingsScreen extends StatelessWidget {
  final String communityId;

  const SettingsScreen({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('設定'),
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF00008b),
        ),
        body: Center(child: Text('設定画面')),
      );
}

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
                          'チャットで /YYYYMMDD を入力して\n予定を追加できます',
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
