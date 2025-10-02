import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/bloc/Userinfo_bloc/Userinfo_bloc.dart';
import 'package:parts/map_page/map_subsc.dart';
import 'package:parts/map_page/map_subsc_en.dart';
import 'package:parts/post_page/timeline_screen.dart';
import 'package:parts/post_page/timeline_screen_en.dart';
import 'package:parts/ranking/ranking_top.dart';
import 'package:parts/shop/shop_maintenance.dart';
import 'package:parts/shop/shop_top.dart';
import 'package:parts/spot_page/anime_list_en_new.dart';

import '../point_page/point_update.dart';
import '../post_page/post_first/post_welcome.dart';
import '../ranking/ranking_top_en.dart';
import '../spot_page/anime_list_test_ranking.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parts/map_page/map_subsc.dart';
import 'package:parts/map_page/map_subsc_en.dart';
import 'package:parts/post_page/timeline_screen.dart';
import 'package:parts/post_page/timeline_screen_en.dart';
import 'package:parts/ranking/ranking_top.dart';
import 'package:parts/shop/shop_maintenance.dart';
import 'package:parts/shop/shop_top.dart';
import 'package:parts/spot_page/anime_list_en_new.dart';

import '../point_page/point_update.dart';
import '../post_page/post_first/post_welcome.dart';
import '../ranking/ranking_top_en.dart';
import '../spot_page/anime_list_test_ranking.dart';

class MainScreen extends StatefulWidget {
  final int initalIndex;

  const MainScreen({Key? key, this.initalIndex = 0}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initalIndex;
    _pageController = PageController(initialPage: widget.initalIndex);

    // Initialize user data through BLoC
    context.read<UserBloc>().add(InitializeUser());
  }

  void _onItemTapped(int index) async {
    final state = context.read<UserBloc>().state;

    if (state is! UserDataLoaded) return;

    String tabName = '';
    switch (index) {
      case 0:
        tabName = 'spot_tab';
        break;
      case 1:
        tabName = 'genre_tab';
        break;
      case 2:
        tabName = 'map_tab';
        break;
      case 3:
        tabName = 'community_tab';
        break;
      case 4:
        tabName = 'ranking_tab';
        break;
    }

    await _analytics.logEvent(
      name: 'bottom_nav_tap',
      parameters: {
        'tab_name': tabName,
        'user_language': state.language,
        'user_id': state.user.uid,
      },
    );

    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  Widget _buildShopScreen() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('shopMaintenance').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ShopHomeScreen();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return ShopHomeScreen();
        }

        // 現在時刻を取得
        final now = DateTime.now();

        // メンテナンス情報をチェック
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final startTime = (data['startTime'] as Timestamp).toDate();
          final endTime = (data['endTime'] as Timestamp).toDate();

          if (now.isAfter(startTime) && now.isBefore(endTime)) {
            return MaintenanceScreen();
          }
        }

        return ShopHomeScreen();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        // Handle loading state
        if (state is UserLoading || state is UserInitial) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Handle error state
        if (state is UserError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.message}'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<UserBloc>().add(InitializeUser());
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // Handle loaded state
        if (state is UserDataLoaded) {
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
                state.language == 'Japanese'
                    ? AnimeListTestRanking()
                    : AnimeListEnNew(),
                state.language == 'Japanese'
                    ? RankingTopPage()
                    : RankingTopPageEn(),
                state.language == 'Japanese'
                    ? MapSubscription(latitude: 37.7749, longitude: -122.4194)
                    : MapSubscriptionEn(
                        latitude: 37.7749, longitude: -122.4194),
                state.language == 'Japanese'
                    ? (!state.hasSeenWelcome
                        ? PostWelcome1(showScaffold: false)
                        : TimelineScreen())
                    : (!state.hasSeenWelcome
                        ? PostWelcome1(showScaffold: false)
                        : TimelineScreenEn()),
                UserPointUpdatePage(), // Same for both languages
              ],
            ),
            bottomNavigationBar: CustomBottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              language: state.language,
            ),
          );
        }

        // Fallback for unknown state
        return Scaffold(
          body: Center(child: Text('Unknown state')),
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
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.black,
      selectedLabelStyle: const TextStyle(
        fontSize: 10,
        color: Colors.black,
      ),
      unselectedLabelStyle: const TextStyle(color: Colors.grey, fontSize: 10),
      unselectedItemColor: Colors.grey,
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.place),
          label: language == 'Japanese' ? 'スポット' : 'Spot',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          label: language == 'Japanese' ? 'イベント' : 'Event',
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
          icon: Icon(Icons.score_outlined),
          label: language == 'Japanese' ? 'ランキング' : 'Ranking',
        ),
      ],
    );
  }
}