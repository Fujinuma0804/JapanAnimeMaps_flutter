import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parts/bloc/map_bloc/map_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parts/map_page/background_location.dart';
import 'package:parts/map_page/notification_service.dart';
import 'package:video_player/video_player.dart';

import '../map_page/admob/admanager.dart';
import '../spot_page/anime_list_test_ranking.dart' hide AdManager;

class MapSubscription extends StatefulWidget {
  final double longitude;
  final double latitude;

  const MapSubscription(
      {Key? key, required this.longitude, required this.latitude})
      : super(key: key);

  @override
  State<MapSubscription> createState() => _MapSubscriptionState();
}

class _MapSubscriptionState extends State<MapSubscription> {
  // UI state variables that don't belong in BLoC
  bool _showConfirmation = false;
  bool _isSubmitting = false;
  bool _isFavorite = false;

  // Search related UI state
  TextEditingController _searchController = TextEditingController();
  FocusNode _searchFocusNode = FocusNode();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;

  // Ad and subscription related state
  bool _isWatchingAd = false;
  bool _isAdAvailable = false;
  bool _isSubscriptionActive = false;
  bool _isCheckingSubscription = false;
  int _searchesRemaining = 3;
  bool _searchLimitReached = false;

  // Video player
  late VideoPlayerController _videoPlayerController;

  // Route related state
  String _selectedTravelMode = 'DRIVE';
  String? _routeDuration;
  String? _routeDistance;

  // Nearby markers loading state
  bool _isLoadingNearbyMarkers = false;
  List<QueryDocumentSnapshot<Object?>> _pendingMarkers = [];
  int _markerBatchSize = 10;
  bool _isLoadingMoreMarkers = false;

  // Map style configuration
  static const String _mapStyle = '''
  [
    {
      "featureType": "transit.station",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#3a4762"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#0e1626"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#4e6d70"
        }
      ]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    print('MapSubscription: 🚀 Starting initState...');

    // Initialize services
    NotificationService.initialize();
    LocationService.initialize();

    // Initialize video player
    _videoPlayerController = VideoPlayerController.network('');
    _videoPlayerController.initialize().then((_) {
      setState(() {});
    });

    // Initialize subscription and search limit data
    _checkSubscriptionStatus();
    _loadSearchLimitData();

    // Initialize AdMob with improved error handling
    print('MapSubscription: 🎬 Initializing AdManager...');
    AdManager.initialize().then((_) {
      print('MapSubscription: ✅ AdManager initialized successfully');

      if (mounted) {
        print('MapSubscription: 📡 Adding ad status listener...');
        AdManager.addAdStatusListener(_onAdStatusChanged);

        try {
          final bool initialAvailability = AdManager.isRewardedAdAvailable();
          print(
              'MapSubscription: 📊 Initial ad availability check: $initialAvailability');

          setState(() {
            _isAdAvailable = initialAvailability;
            print(
                'MapSubscription: ✅ Initial ad availability set to: $_isAdAvailable');
          });

          _printDebugInfo();
        } catch (e) {
          print('MapSubscription: ❌ Error setting initial ad availability: $e');
          print('MapSubscription: Stack trace: ${StackTrace.current}');
        }
      }
    }).catchError((error) {
      print('MapSubscription: ❌ Error initializing AdManager: $error');
    });

    print('MapSubscription: ✅ initState completed');
  }

  //サブスクリプション状態をチェックするメソッド【追加】
  Future<void> _checkSubscriptionStatus() async {
    setState(() {
      _isCheckingSubscription = true;
    });

    try {
      await SubscriptionManager.initialize();
      bool isActive = await SubscriptionManager.isSubscriptionActive();

      if (mounted) {
        setState(() {
          _isSubscriptionActive = isActive;
          _isCheckingSubscription = false;
        });
      }
      print('MapSubscription: サブスクリプション状態確認完了-isActive: $isActive');
    } catch (e) {
      print('MapSubscription: サブスクリプション状態確認エラー: $e');

      if (mounted) {
        setState(() {
          _isSubscriptionActive = false;
          _isCheckingSubscription = false;
        });
      }
    }
  }

  // デバッグ情報を表示するメソッド
  void _printDebugInfo() {
    print('=== MapSubscription Debug Info ===');
    print('_isAdAvailable: $_isAdAvailable');
    print('_searchLimitReached: $_searchLimitReached');
    print('_searchesRemaining: $_searchesRemaining');
    print('_isWatchingAd: $_isWatchingAd');
    print('AdManager debug info: ${AdManager.getDebugInfo()}');
    print('================================');
  }

  // 広告ステータス変更リスナーを修正（デバッグ強化）
  void _onAdStatusChanged(bool available) {
    print('MapSubscription: 📢 Ad status changed to: $available');
    print('MapSubscription: Widget mounted: $mounted');
    print('MapSubscription: Current searchLimitReached: $_searchLimitReached');

    // ウィジェットがまだマウントされているかチェック
    if (!mounted) {
      print('MapSubscription: ⚠️ Widget not mounted, skipping setState');
      return;
    }

    // ウィジェットの状態が有効かチェック
    try {
      setState(() {
        _isAdAvailable = available;
        print('MapSubscription: ✅ Ad availability updated to $_isAdAvailable');
      });

      // デバッグ情報を出力
      _printDebugInfo();
    } catch (e) {
      print('MapSubscription: ❌ Error updating ad status: $e');
      print('MapSubscription: Stack trace: ${StackTrace.current}');
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    AdManager.removeAdStatusListener(_onAdStatusChanged);
    AdManager.dispose(); // Dispose AdMob resources
    super.dispose();
  }

  // 検索制限データをFirestoreからロードする新しいメソッド
  Future<void> _loadSearchLimitData() async {
    print('===検索制限データ読み込み開始＝＝＝');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 現在のユーザーの検索使用状況ドキュメントを取得
      DocumentSnapshot searchUsageDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('search_usage')
          .doc('daily_limit')
          .get();

      if (searchUsageDoc.exists) {
        Map<String, dynamic> data =
            searchUsageDoc.data() as Map<String, dynamic>;
        DateTime lastSearchDate =
            (data['lastSearchDate'] as Timestamp).toDate();
        int searchCount = data['searchCount'] ?? 0;

        print('Firebaseから取得したデータ');
        print(' searchCount: $searchCount');
        print(' lastSearchDate: $lastSearchDate');
        print(' 現在時刻: ${DateTime.now()}');

        // 最後の検索が別の日（午前0時以降）に行われたかチェック
        bool isNewDay = DateTime.now().day != lastSearchDate.day ||
            DateTime.now().month != lastSearchDate.month ||
            DateTime.now().year != lastSearchDate.year;

        if (isNewDay) {
          // 新しい日なので検索カウントをリセット
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('search_usage')
              .doc('daily_limit')
              .update({
            'searchCount': 0,
            'lastSearchDate': FieldValue.serverTimestamp(),
          });

          setState(() {
            _searchesRemaining = 3;
            _searchLimitReached = false;
          });
        } else {
          // 同じ日なので現在のカウントを使用
          setState(() {
            _searchesRemaining = math.max(0, 3 - searchCount);
            _searchLimitReached = _searchesRemaining <= 0;
          });
        }
      } else {
        // ドキュメントが存在しない場合は新規作成
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('search_usage')
            .doc('daily_limit')
            .set({
          'searchCount': 0,
          'lastSearchDate': FieldValue.serverTimestamp(),
        });

        setState(() {
          _searchesRemaining = 3;
          _searchLimitReached = false;
        });
      }

      print('検索制限データ読み込み完了');
      print('_searchesRemaining: $_searchesRemaining');
      print('_searchLimitReached: $_searchLimitReached');
    } catch (e) {
      print('検索制限データ読み込みエラー: $e');
      setState(() {
        _searchesRemaining = 3;
        _searchLimitReached = false;
      });
    }
  }

  Widget _buildLoadingIndicators(BuildContext context) {
    return Stack(
      children: [
        // Loading indicator for nearby markers
        if (_isLoadingNearbyMarkers)
          Positioned(
            bottom: 100,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('マーカーを読み込み中...'),
                ],
              ),
            ),
          ),

        // Loading indicator for marker batch processing
        if (_isLoadingMoreMarkers)
          Positioned(
            bottom: 160,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('マーカーを処理中...'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MapBloc()..add(MapInitialized()),
      child: BlocConsumer<MapBloc, MapState>(
        listener: (context, state) {
          if (state is MapError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }

          // Update search results from BLoC state
          if (state is MapLoaded && state.searchResults.isNotEmpty) {
            setState(() {
              _searchResults = state.searchResults;
            });
          }
        },
        builder: (context, state) {
          return Scaffold(
            resizeToAvoidBottomInset: true,
            body: Stack(
              children: [
                // Map based on BLoC state
                _buildMapContent(context, state),

                // UI overlays
                _buildSearchBar(context),
                _buildLocationButton(context, state),
                _buildRouteInfo(context, state),
                _buildSearchResults(context),
                _buildBottomSheet(context, state),
                _buildSearchLimitInfo(context),
                _buildLoadingIndicators(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapContent(BuildContext context, MapState state) {
    if (state is MapLoading || state is MapInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is MapLoaded) {
      return Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: state.currentPosition ??
                  LatLng(widget.latitude, widget.longitude),
              zoom: 14,
            ),
            markers: state.markers,
            circles: state.circles,
            polylines: state.polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) {
              context.read<MapBloc>().add(MapCreated(controller));
              controller.setMapStyle(_mapStyle);
            },
            onCameraIdle: () {
              // Automatically load nearby markers when camera stops moving
              _loadNearbyMarkers();
            },
            onTap: (position) {
              // Clear search results when tapping on map
              setState(() {
                _searchResults.clear();
              });
            },
          ),
          // Floating button for loading/printing nearby locations
          Positioned(
            bottom: 10,
            left: 20,
            child: FloatingActionButton.extended(
              heroTag: 'nearby',
              backgroundColor: Colors.green,
              onPressed: () async {
                await _loadNearbyMarkers();
                final mapBloc = context.read<MapBloc>();
                final blocState = mapBloc.state;
                if (blocState is MapLoaded &&
                    blocState.currentPosition != null) {
                  final userPos = blocState.currentPosition!;
                  final nearby = blocState.markers.where((m) {
                    final d = Geolocator.distanceBetween(
                      userPos.latitude,
                      userPos.longitude,
                      m.position.latitude,
                      m.position.longitude,
                    );
                    return d < 1000; // 1km radius
                  }).toList();
                  print('Nearby locations:');
                  for (final m in nearby) {
                    print('  ${m.markerId.value} at ${m.position}');
                  }
                  if (nearby.isEmpty) print('No nearby locations found.');
                } else {
                  print('Current position unknown.');
                }
              },
              label: const Text(
                'Nearby',
                style: TextStyle(
                  color: Colors.white, // ✅ White text
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      );
    }

    return const Center(child: Text('予期しない状態です'));
  }

  Widget _buildSearchBar(BuildContext context) {
    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: '場所を検索...',
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults.clear();
                      });
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() {});
            if (value.isNotEmpty) {
              _performSearch(value);
            } else {
              setState(() {
                _searchResults.clear();
              });
            }
          },
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _performSearch(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildLocationButton(BuildContext context, MapState state) {
    return Positioned(
      bottom: 100,
      right: 16,
      child: FloatingActionButton(
        onPressed: () {
          context.read<MapBloc>().add(CurrentLocationRequested());
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  Widget _buildRouteInfo(BuildContext context, MapState state) {
    if (state is! MapLoaded || state.routeDuration == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 120,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.directions, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ルート情報',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text('距離: ${state.routeDistance}'),
                  Text('時間: ${state.routeDuration}'),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                // Clear route info - you can add BLoC event here
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    if (_searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 110,
      left: 16,
      right: 16,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final result = _searchResults[index];
            final data = result.data() as Map<String, dynamic>;

            return ListTile(
              leading: const Icon(Icons.location_on, color: Colors.blue),
              title: Text(data['title'] ?? 'No title'),
              subtitle: Text(data['animeName'] ?? ''),
              onTap: () {
                final position = LatLng(
                  (data['latitude'] as num).toDouble(),
                  (data['longitude'] as num).toDouble(),
                );
                context
                    .read<MapBloc>()
                    .add(MarkerSelected(result.id, position));
                _searchFocusNode.unfocus();
                setState(() {
                  _searchResults.clear();
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context, MapState state) {
    if (state is! MapLoaded || state.selectedMarker == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle for dragging
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Marker info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marker Title', // You'll need to get this from the marker data
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Distance: ${state.routeDistance ?? 'N/A'}'),
                    ],
                  ),
                ),
                Column(
                  children: [
                    FloatingActionButton.small(
                      onPressed: () {
                        context
                            .read<MapBloc>()
                            .add(FavoriteToggled('marker_id'));
                      },
                      backgroundColor:
                          state.isFavorite ? Colors.red : Colors.grey,
                      child: Icon(
                        state.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (state.canCheckIn && !state.hasCheckedIn)
                      ElevatedButton(
                        onPressed: () {
                          context
                              .read<MapBloc>()
                              .add(CheckInRequested('location_id', 'title'));
                        },
                        child: const Text('チェックイン'),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchLimitInfo(BuildContext context) {
    if (_isSubscriptionActive || _searchesRemaining > 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 120,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '検索制限に達しました',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '広告を視聴するかプレミアムにアップグレードしてください',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            if (_isAdAvailable)
              ElevatedButton(
                onPressed: _watchAd,
                child: const Text('広告を視聴'),
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to perform search
  Future<void> _performSearch(String query) async {
    if (_searchLimitReached && !_isSubscriptionActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('検索制限に達しました。広告を視聴するか、プレミアムにアップグレードしてください。'),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // If search limit reached, show alert dialog
      if (_searchLimitReached) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('検索上限エラー'),
              content: const Text('今日の検索上限に達しました。広告を視聴して回数をリセットできます。'),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _watchAd();
                  },
                  child: const Text('広告を視聴'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('キャンセル'),
                ),
              ],
            );
          },
        );
        return;
      }
      // Use the BLoC search functionality
      context.read<MapBloc>().add(SearchPerformed(query));

      // Update search limit
      setState(() {
        _searchesRemaining--;
        if (_searchesRemaining <= 0) {
          _searchLimitReached = true;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('検索中にエラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Helper method to watch ad
  Future<void> _watchAd() async {
    setState(() {
      _isWatchingAd = true;
    });

    try {
      // await AdManager.showRewardedAd();
      setState(() {
        _searchesRemaining = 3;
        _searchLimitReached = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('広告を視聴しました。検索回数がリセットされました。'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('広告の再生に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isWatchingAd = false;
      });
    }
  }

  // Load markers from the current camera position
  // Load markers from the current camera position
  Future<void> _loadNearbyMarkers() async {
    if (_isLoadingNearbyMarkers) return;

    setState(() {
      _isLoadingNearbyMarkers = true;
    });

    try {
      // Get current camera position from BLoC state
      final mapBloc = context.read<MapBloc>();
      final state = mapBloc.state;

      if (state is! MapLoaded || state.currentPosition == null) {
        print('❌ Cannot load markers: Map not loaded or no current position');
        return;
      }

      final center = state.currentPosition!;
      print(
          '📍 Current center position: ${center.latitude}, ${center.longitude}');

      double distanceInMeters = 5000; // Default radius
      print('🔍 Search radius: ${distanceInMeters}m');

      // Get all locations from Firestore
      print('🔥 Fetching locations from Firestore...');
      CollectionReference locations =
          FirebaseFirestore.instance.collection('locations');
      QuerySnapshot snapshot = await locations.get();

      print('📊 Total documents in collection: ${snapshot.docs.length}');

      List<QueryDocumentSnapshot<Object?>> nearbyDocs = [];
      int validDocs = 0;
      int skippedInvalidCoords = 0;
      int skippedExisting = 0;
      int withinRadius = 0;

      // Filter documents manually
      for (var doc in snapshot.docs) {
        print('\n📄 Processing document: ${doc.id}');

        // Safely get data with null checks
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print('   Raw data: $data');

        // Skip documents without valid latitude/longitude
        if (data['latitude'] == null || data['longitude'] == null) {
          print('   ❌ Skipped: Missing latitude/longitude');
          skippedInvalidCoords++;
          continue;
        }

        // Safely convert to double with null checks
        double? lat = data['latitude'] is num
            ? (data['latitude'] as num).toDouble()
            : null;
        double? lng = data['longitude'] is num
            ? (data['longitude'] as num).toDouble()
            : null;

        // Skip if valid coordinates couldn't be obtained
        if (lat == null || lng == null) {
          print('   ❌ Skipped: Invalid coordinate format');
          skippedInvalidCoords++;
          continue;
        }

        validDocs++;
        print('   ✅ Valid coordinates: $lat, $lng');

        double distance = Geolocator.distanceBetween(
            center.latitude, center.longitude, lat, lng);
        print('   📏 Distance from center: ${distance.toStringAsFixed(2)}m');

        // Check if this marker already exists on the map
        bool alreadyExists =
            state.markers.any((marker) => marker.markerId.value == doc.id);
        print('   🎯 Already on map: $alreadyExists');

        bool withinDistance = distance <= distanceInMeters * 1.5;
        print('   📍 Within radius: $withinDistance');

        if (!alreadyExists && withinDistance) {
          nearbyDocs.add(doc);
          withinRadius++;
          print('   ✅ ADDED to nearby markers');
        } else {
          skippedExisting++;
          print('   ❌ Skipped: Already exists or outside radius');
        }
      }

      print('\n📈 SUMMARY:');
      print('   Total documents: ${snapshot.docs.length}');
      print('   Valid documents: $validDocs');
      print('   Skipped (invalid coordinates): $skippedInvalidCoords');
      print('   Skipped (existing/outside radius): $skippedExisting');
      print('   Nearby markers found: $withinRadius');
      print('   Current pending markers: ${_pendingMarkers.length}');

      // Update _pendingMarkers directly without using addAll
      setState(() {
        _pendingMarkers = [..._pendingMarkers, ...nearbyDocs];
      });

      print('   New pending markers count: ${_pendingMarkers.length}');

      // Process the batch
      print('🔄 Processing marker batch...');
      await _processMarkerBatch();
      print('✅ Marker batch processing completed');
    } catch (e) {
      print('❌ Error loading nearby markers: $e');
      print('🚨 Stack trace: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingNearbyMarkers = false;
      });
      print('🏁 Loading completed. _isLoadingNearbyMarkers: false');
    }
  }

  // Process marker batch
  Future<void> _processMarkerBatch() async {
    if (_pendingMarkers.isEmpty || _isLoadingMoreMarkers) return;

    setState(() {
      _isLoadingMoreMarkers = true;
    });

    try {
      // Take a batch of markers to process
      final batchToProcess = _pendingMarkers.take(_markerBatchSize).toList();

      // Remove processed markers from pending list
      setState(() {
        _pendingMarkers = _pendingMarkers.skip(_markerBatchSize).toList();
      });

      // Create markers from the batch
      final Set<Marker> newMarkers = {};

      for (var doc in batchToProcess) {
        final data = doc.data() as Map<String, dynamic>;

        if (data['latitude'] != null && data['longitude'] != null) {
          final position = LatLng(
            (data['latitude'] as num).toDouble(),
            (data['longitude'] as num).toDouble(),
          );

          final marker = Marker(
            markerId: MarkerId(doc.id),
            position: position,
            onTap: () {
              context.read<MapBloc>().add(MarkerSelected(doc.id, position));
            },
          );

          newMarkers.add(marker);
        }
      }

      // Add markers to the map via BLoC
      if (newMarkers.isNotEmpty) {
        context.read<MapBloc>().add(MarkersLoadRequested());
      }
    } catch (e) {
      print('Error processing marker batch: $e');
    } finally {
      setState(() {
        _isLoadingMoreMarkers = false;
      });
    }
  }
}

class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> postData;

  const PostDetailScreen({Key? key, required this.postData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '投稿',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              postData['title'] ?? 'No title',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              postData['description'] ?? 'No description',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
