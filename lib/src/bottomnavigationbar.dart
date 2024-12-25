import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:parts/post_page/timeline_screen.dart';
import 'package:parts/shop/screens/product_list_screen.dart';

import '../map_page/map.dart';
import '../map_page/map_en.dart';
import '../point_page/point_update.dart';
import '../post_page/post_first/post_welcome.dart';
import '../ranking/ranking_top_en.dart';
import '../spot_page/anime_list_ranking_en.dart';
import '../spot_page/anime_list_test_ranking.dart';

class MainScreen extends StatefulWidget {
  final int initalIndex;

  const MainScreen({Key? key, this.initalIndex = 0}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController = PageController();
  late User _user;
  String _userLanguage = 'English';
  late Stream<DocumentSnapshot> _userStream;
  double _latitude = 37.7749;
  double _longitude = -122.4194;
  bool _hasSeenWelcome = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initalIndex;
    _pageController = PageController(initialPage: widget.initalIndex);
    _getUser();
    _updateCorrectCount();
    _setupUserStream();
    _checkWelcomeStatus();
  }

  Future<void> _getUser() async {
    _user = FirebaseAuth.instance.currentUser!;
  }

  void _setupUserStream() {
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .snapshots();

    _userStream.listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        setState(() {
          _userLanguage =
              (snapshot.data() as Map<String, dynamic>)['language'] ??
                  'English';
          print('User language: $_userLanguage');
        });
      }
    });
  }

  Future<void> _checkWelcomeStatus() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .get();

    if (userDoc.exists) {
      setState(() {
        _hasSeenWelcome =
            (userDoc.data() as Map<String, dynamic>)['hasSeenWelcome'] ?? false;
      });
    }
  }

  Future<void> _updateCorrectCount() async {
    try {
      int correctCount = 0;
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .collection('check_ins')
          .get();

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['isCorrect'] == true) {
          correctCount++;
        }
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .get();

      if (userDoc.exists) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user.uid)
            .update({'correctCount': correctCount});
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user.uid)
            .set({
          'correctCount': correctCount,
          'hasSeenWelcome': false,
          'language': _userLanguage,
        });
      }
    } catch (e) {
      print('Error updating correct count: $e');
    }
  }

  void _onItemTapped(int index) async {
    bool canVibrate = await Vibrate.canVibrate;
    if (canVibrate) {
      Vibrate.feedback(FeedbackType.selection);
    }

    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData != null) {
            _userLanguage = userData['language'] ?? 'English';
            _hasSeenWelcome = userData['hasSeenWelcome'] ?? false;
          }
        }

        return Scaffold(
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: [
              _userLanguage == 'Japanese'
                  ? AnimeListTestRanking()
                  : AnimeListTestRankingEng(),
              _userLanguage == 'Japanese'
                  ? ProductListScreen()
                  : RankingTopPageEn(),
              _userLanguage == 'Japanese'
                  ? MapScreen(latitude: _latitude, longitude: _longitude)
                  : MapEnScreen(latitude: _latitude, longitude: _longitude),
              _userLanguage == 'Japanese'
                  ? (!_hasSeenWelcome
                      ? PostWelcome1(showScaffold: false)
                      : TimelineScreen())
                  : (!_hasSeenWelcome
                      ? PostWelcome1(showScaffold: false)
                      : TimelineScreen()),
              _userLanguage == 'Japanese'
                  ? UserPointUpdatePage()
                  : UserPointUpdatePage(),
            ],
          ),
          bottomNavigationBar: CustomBottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            language: _userLanguage,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final String language;

  const CustomBottomNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.language,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF00008b),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.white,
      selectedLabelStyle: const TextStyle(
        fontSize: 10,
        color: Colors.white,
      ),
      unselectedLabelStyle: const TextStyle(color: Colors.white, fontSize: 10),
      unselectedItemColor: Colors.white,
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.place),
          label: language == 'Japanese' ? 'スポット' : 'Spot',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_bag_outlined),
          label: language == 'Japanese' ? 'ジャンル' : 'Genre',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: language == 'Japanese' ? '地図' : 'Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_outlined),
          label: language == 'Japanese' ? 'コミュニティ' : 'Community',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: language == 'Japanese' ? 'その他' : 'Other',
        ),
      ],
    );
  }
}
