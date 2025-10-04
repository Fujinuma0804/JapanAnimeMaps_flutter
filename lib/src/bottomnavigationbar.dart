import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parts/Prensantionlayer/CameraCompositionScreen/CameraCompositionScreen.dart';
import 'package:parts/bloc/Userinfo_bloc/Userinfo_bloc.dart';
import 'package:parts/map_page/map_subsc.dart';
import 'package:parts/map_page/map_subsc_en.dart';
import 'package:parts/post_page/timeline_screen.dart';
import 'package:parts/post_page/timeline_screen_en.dart';
import 'package:parts/point_page/point_update.dart';
import 'package:parts/post_page/post_first/post_welcome.dart';
import 'package:parts/spot_page/anime_list_en_new.dart';
import 'package:parts/spot_page/anime_list_test_ranking.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  late User _user;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _user = FirebaseAuth.instance.currentUser!;

    // Initialize user data through BLoC
    context.read<UserBloc>().add(InitializeUser());
  }

  void _refreshMainScreen() {
    setState(() {
      _refreshKey++;
    });
  }

  void _onItemTapped(int index) async {
    String tabName = '';
    switch (index) {
      case 0:
        tabName = 'spot_tab';
        break;
      case 1:
        tabName = 'map_tab';
        break;
      case 2:
        tabName = 'camera_tab';
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Handle error state
        if (state is UserError) {
          return Scaffold(
            body: Center(child: Text('Error: ${state.message}')),
          );
        }

        // Handle loaded state
        if (state is UserDataLoaded) {
          return Scaffold(
            body: PageView(
              key: ValueKey(_refreshKey),
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: _buildPages(state),
            ),
            bottomNavigationBar: CustomBottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              language: state.language,
            ),
          );
        }

        // Fallback for unknown state
        return const Scaffold(
          body: Center(child: Text('Unknown state')),
        );
      },
    );
  }

  List<Widget> _buildPages(UserDataLoaded state) {
    return [
      // Page 0: Spot
      state.language == 'Japanese'
          ? AnimeListTestRanking()
          : const AnimeListEnNew(),

      // Page 1: Map
      state.language == 'Japanese'
          ? MapSubscription(latitude: 37.7749, longitude: -122.4194)
          : MapSubscriptionEn(latitude: 37.7749, longitude: -122.4194),

      // Page 2: Camera
      CameraCompositionScreen(
        onBackPressed: _refreshMainScreen,
      ),

      // Page 3: Community
      state.language == 'Japanese'
          ? (!state.hasSeenWelcome
              ? PostWelcome1(showScaffold: false)
              : const TimelineScreen())
          : (!state.hasSeenWelcome
              ? PostWelcome1(showScaffold: false)
              : const TimelineScreenEn()),

      // Page 4: Ranking
      const UserPointUpdatePage(),
    ];
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
        BottomNavigationBarItem(
          icon: const Icon(Icons.map),
          label: language == 'Japanese' ? '地図' : 'Map',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.add),
          label: "",
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.chat_outlined),
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
