import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:parts/post_page/timeline_screen.dart';

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
      icon: Icons.photo_library,
      title: '写真・動画',
      color: Colors.purple,
    ),
    MenuOption(
      icon: Icons.note,
      title: 'ノート',
      color: Colors.teal,
    ),
    MenuOption(
      icon: Icons.link,
      title: 'リンク',
      color: Colors.indigo,
    ),
    MenuOption(
      icon: Icons.history,
      title: '履歴',
      color: Colors.brown,
    ),
    MenuOption(
      icon: Icons.bar_chart,
      title: '分析',
      color: Colors.deepPurple,
    ),
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
        _handleMedia(context);
        break;
      case 1:
        _handleNotes(context);
        break;
      case 2:
        _handleLinks(context);
        break;
      case 3:
        _handleHistory(context);
        break;
      case 4:
        _handleAnalytics(context);
        break;
      case 5:
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

  void _handleMedia(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaGalleryScreen(communityId: communityId),
      ),
    );
  }

  void _handleNotes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotesScreen(communityId: communityId),
      ),
    );
  }

  void _handleLinks(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LinksScreen(communityId: communityId),
      ),
    );
  }

  void _handleHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatHistoryScreen(communityId: communityId),
      ),
    );
  }

  void _handleAnalytics(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalyticsScreen(communityId: communityId),
      ),
    );
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
        appBar: AppBar(title: Text('メンバー')),
        body: Center(child: Text('メンバー画面')),
      );
}

class MediaGalleryScreen extends StatelessWidget {
  final String communityId;

  const MediaGalleryScreen({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('写真・動画')),
        body: Center(child: Text('メディアギャラリー画面')),
      );
}

class NotesScreen extends StatelessWidget {
  final String communityId;

  const NotesScreen({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('ノート')),
        body: Center(child: Text('ノート画面')),
      );
}

class EventsScreen extends StatelessWidget {
  final String communityId;

  const EventsScreen({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('イベント')),
        body: Center(child: Text('イベント画面')),
      );
}

class LinksScreen extends StatelessWidget {
  final String communityId;

  const LinksScreen({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('リンク')),
        body: Center(child: Text('リンク画面')),
      );
}

class ChatHistoryScreen extends StatelessWidget {
  final String communityId;

  const ChatHistoryScreen({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('トーク履歴')),
        body: Center(child: Text('トーク履歴画面')),
      );
}

class AnalyticsScreen extends StatelessWidget {
  final String communityId;

  const AnalyticsScreen({
    Key? key,
    required this.communityId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('分析')),
        body: Center(child: Text('分析画面')),
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
        appBar: AppBar(title: Text('設定')),
        body: Center(child: Text('設定画面')),
      );
}
