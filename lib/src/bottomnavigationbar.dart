import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as snapshot;
import 'package:parts/Prensantionlayer/CameraCompositionScreen/CameraCompositionScreen.dart';
import 'package:parts/bloc/Userinfo_bloc/Userinfo_bloc.dart';
import 'package:parts/map_page/map_subsc.dart';
import 'package:parts/map_page/map_subsc_en.dart';
import 'package:parts/post_page/timeline_screen.dart';
import 'package:parts/post_page/timeline_screen_en.dart';
import 'package:parts/shop/shop_maintenance.dart';
import 'package:parts/shop/shop_top.dart';
import 'package:parts/spot_page/anime_list_en_new.dart';
import 'package:parts/test/books.dart';
import 'package:parts/test/posts_photo.dart';

import '../point_page/point_update.dart';
import '../post_page/post_first/post_welcome.dart';
import '../spot_page/anime_list_test_ranking.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

class MainScreen extends StatefulWidget {
  final int initalIndex;

  const MainScreen({super.key, this.initalIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController = PageController();
  late User _user;
  String _userLanguage = 'English';
  late Stream<DocumentSnapshot> _userStream;
  final double _latitude = 37.7749;
  final double _longitude = -122.4194;
  bool _hasSeenWelcome = false;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  int _refreshKey = 0; // Key to force refresh of pages

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initalIndex;
    _pageController = PageController(initialPage: widget.initalIndex);

    // Initialize user data through BLoC
    context.read<UserBloc>().add(InitializeUser());
  }

  void _refreshMainScreen() {
    setState(() {
      _refreshKey++; // Increment refresh key to force refresh of all pages
    });
  }

  void _onItemTapped(int index) async {
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
        'user_language': _userLanguage,
        'user_id': _user.uid,
      },
    );

    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
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

        // Remove incorrect snapshot checks, handle errors via BLoC state
        if (state is UserError) {
          return Scaffold(
            body: Center(child: Text('Error: ${state.message}')),
          );
        }

        // Handle loaded state
        if (state is UserDataLoaded) {
          return Scaffold(
            body: PageView(
              key: ValueKey(_refreshKey), // Use refresh key to force refresh
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
                    ? MapSubscription(latitude: 37.7749, longitude: -122.4194)
                    : MapSubscriptionEn(
                        latitude: 37.7749, longitude: -122.4194),
                state.language == 'Japanese'
                    ? CameraCompositionScreen(
                        onBackPressed: _refreshMainScreen,
                      )
                    : CameraCompositionScreen(
                        onBackPressed: _refreshMainScreen,
                      ),
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
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.language,
  });

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
          icon: const Icon(Icons.place),
          label: language == 'Japanese' ? 'スポット' : 'Spot',
        ),

        // BottomNavigationBarItem(
        //   icon: Icon(Icons.calendar_today_outlined),
        //   label: language == 'Japanese' ? 'イベント' : 'Event',
        // ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: language == 'Japanese' ? '地図' : 'Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add),
          label: "",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_outlined),
          label: language == 'Japanese' ? 'コミュニティ' : 'Community',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.score_outlined),
          label: language == 'Japanese' ? 'ランキング' : 'Ranking',
        ),
      ],
    );
  }
}