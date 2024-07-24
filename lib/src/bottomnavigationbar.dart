import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/manual_page/manual.dart';
import 'package:parts/map_page/map.dart';
import 'package:parts/search_page/search.dart';
import 'package:parts/web_page/website.dart';

import '../point_page/point.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  late User _user;

  @override
  void initState() {
    super.initState();
    _getUser();
    _updateCorrectCount();
  }

  Future<void> _getUser() async {
    _user = FirebaseAuth.instance.currentUser!;
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: const [
          MapScreen(),
          WebsiteScreen(),
          SearchPage(),
          PointPage(),
          Manual(),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
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
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.map), label: '地図'),
        BottomNavigationBarItem(icon: Icon(Icons.web), label: '公式サイト'),
        BottomNavigationBarItem(icon: Icon(Icons.place), label: 'スポット'),
        BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on), label: 'ポイント'),
        BottomNavigationBarItem(icon: Icon(Icons.description), label: 'その他'),
      ],
    );
  }
}
