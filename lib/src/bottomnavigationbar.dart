import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:parts/spot_page/anime_list.dart';

import '../manual_page/manual_en.dart';
import '../map_page/map.dart';
import '../map_page/map_en.dart';
import '../point_page/point_en.dart';
import '../spot_page/anime_list_en.dart';
import '../web_page/website.dart';
import '../web_page/website_en.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  late User _user;
  String _userLanguage = 'English';
  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    _getUser();
    _updateCorrectCount();
    _setupUserStream();
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
        });
      }
    });
  }

  Future<void> _updateCorrectCount() async {
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

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .update({'correctCount': correctCount});
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
          return CircularProgressIndicator();
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
              _userLanguage == 'Japanese' ? MapScreen() : MapEnScreen(),
              _userLanguage == 'Japanese' ? WebsiteScreen() : WebsiteEnScreen(),
              _userLanguage == 'Japanese' ? AnimeListPage() : AnimeListEnPage(),
              _userLanguage == 'Japanese' ? PointEnPage() : PointEnPage(),
              _userLanguage == 'Japanese' ? ManualEn() : ManualEn(),
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
          icon: Icon(Icons.map),
          label: language == 'Japanese' ? '地図' : 'Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.web),
          label: language == 'Japanese' ? '公式サイト' : 'Official Site',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.place),
          label: language == 'Japanese' ? 'スポット' : 'Spot',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.monetization_on),
          label: language == 'Japanese' ? 'ポイント' : 'Point',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.description),
          label: language == 'Japanese' ? 'その他' : 'Other',
        ),
      ],
    );
  }
}
