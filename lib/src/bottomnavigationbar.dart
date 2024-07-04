import 'package:flutter/material.dart';
import 'package:parts/map.dart';
import 'package:parts/spot_page/spot.dart';
import 'package:parts/website.dart';

import '../manual_page/manual.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

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
        physics: const NeverScrollableScrollPhysics(), // スワイプによるページ移動を無効化する
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: const [
          MapScreen(),
          WebsiteScreen(),
          SpotScreen(),
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
      selectedItemColor: Colors.white, // 選択したアイテムのアイコン色
      selectedLabelStyle: const TextStyle(
        fontSize: 10,
        color: Colors.white,
      ), // 選択したアイテムのテキスト色
      unselectedLabelStyle: const TextStyle(color: Colors.white, fontSize: 10),
      unselectedItemColor: Colors.white,
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.map), label: '地図'),
        BottomNavigationBarItem(icon: Icon(Icons.web), label: '公式サイト'),
        BottomNavigationBarItem(icon: Icon(Icons.place), label: 'スポット'),
        BottomNavigationBarItem(
            icon: Icon(Icons.description), label: '使い方・規約等'),
      ],
    );
  }
}
