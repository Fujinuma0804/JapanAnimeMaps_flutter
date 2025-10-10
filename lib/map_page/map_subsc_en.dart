import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:parts/map_page/background_location.dart';
import 'package:parts/map_page/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // 追加
import 'package:shared_preferences/shared_preferences.dart'; // 【追加】
import 'package:purchases_flutter/purchases_flutter.dart'; // 【追加】

import '../PostScreen.dart';
import '../spot_page/anime_list_detail.dart';
// 【修正】正しいAdManagerファイルのみをインポート（もう一つの方をhide）
import '../map_page/admob/admanager.dart';
import '../spot_page/anime_list_test_ranking.dart' hide AdManager;

class MapSubscriptionEn extends StatefulWidget {
  const MapSubscriptionEn(
      {Key? key, required double longitude, required double latitude})
      : super(key: key);

  @override
  State<MapSubscriptionEn> createState() => _MapSubscriptionEnState();
}

class _MapSubscriptionEnState extends State<MapSubscriptionEn> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = true;
  bool _errorOccurred = false;
  bool _canCheckIn = false;
  bool _showConfirmation = false;
  bool _hasCheckedInAlready = false;
  Marker? _selectedMarker;
  late User _user;
  late String _userId;
  bool _isFavorite = false;
  bool _isSubmitting = false;
  int _markerBatchSize = 10;
  bool _isLoadingMoreMarkers = false;
  List<QueryDocumentSnapshot> _pendingMarkers = [];
  bool _isLoadingNearbyMarkers = false;

  // 検索制限に関する変数
  int _searchesRemaining = 3; // デフォルト値（Firestoreからロードするまで）
  bool _searchLimitReached = false;
  DateTime _lastSearchDate = DateTime.now();

  //サブスクリプション関連の変数【追加】
  bool _isSubscriptionActive = false;
  bool _isCheckingSubscription = false;

  // 広告関連の新しい変数
  bool _isWatchingAd = false;
  bool _isAdAvailable = false;

  TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  FocusNode _searchFocusNode = FocusNode();

  late VideoPlayerController _videoPlayerController;
  late Future<void> _initializeVideoPlayerFuture;

  // Google Routes API関連の変数
  Map<PolylineId, Polyline> _routePolylines = {};
  String _selectedTravelMode =
      'DRIVE'; // 'DRIVE', 'WALK', 'BICYCLE', 'TRANSIT'のいずれか
  bool _isLoadingRoute = false;
  String? _routeDuration;
  String? _routeDistance;

  static const double _maxDisplayRadius = 150000;

  static const String _mapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#1d2c4d"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#8ec3b9"
        }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1a3646"
        }
      ]
    },
    {
      "featureType": "administrative.country",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#4b6878"
        }
      ]
    },
    {
      "featureType": "administrative.land_parcel",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#64779e"
        }
      ]
    },
    {
      "featureType": "administrative.province",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#4b6878"
        }
      ]
    },
    {
      "featureType": "landscape.man_made",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#334e87"
        }
      ]
    },
    {
      "featureType": "landscape.natural",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#023e58"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#283d6a"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#6f9ba5"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1d2c4d"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry.fill",
      "stylers": [
        {
          "color": "#023e58"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#3C7680"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#304a7d"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#98a5be"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1d2c4d"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#2c6675"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#255763"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#b0d5ce"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#023e58"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#98a5be"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#1d2c4d"
        }
      ]
    },
    {
      "featureType": "transit.line",
      "elementType": "geometry.fill",
      "stylers": [
        {
          "color": "#283d6a"
        }
      ]
    },
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
    print(
        'MapSubscriptionEn : 🚀 Starting initState with MapBloc optimization...');

    NotificationService.initialize();
    LocationService.initialize();
    _getCurrentLocation();
    _loadMarkersFromFirestore();

    //ユーザ取得とサブスクリプション状態チェックを追加
    _getUser().then((_) async {
      await _checkSubscriptionStatus();
      _loadSearchLimitData();
    });

    // Initialize AdMob with improved error handling
    print('MapSubscriptionEn : 🎬 Initializing AdManager...');
    AdManager.initialize().then((_) {
      print('MapSubscriptionEn : ✅ AdManager initialized successfully');

      // mountedチェックを追加
      if (mounted) {
        print('MapSubscriptionEn : 📡 Adding ad status listener...');
        AdManager.addAdStatusListener(_onAdStatusChanged);

        // 初期状態を安全に設定
        try {
          final bool initialAvailability = AdManager.isRewardedAdAvailable();
          print(
              'MapSubscriptionEn : 📊 Initial ad availability check: $initialAvailability');

          setState(() {
            _isAdAvailable = initialAvailability;
            print(
                'MapSubscriptionEn : ✅ Initial ad availability set to: $_isAdAvailable');
          });

          _printDebugInfo();
        } catch (e) {
          print(
              'MapSubscriptionEn : ❌ Error setting initial ad availability: $e');
          print('MapSubscriptionEn : Stack trace: ${StackTrace.current}');
        }
      } else {
        print(
            'MapSubscriptionEn : ⚠️ Widget not mounted after AdManager initialization');
      }
    }).catchError((error) {
      print('MapSubscriptionEn : ❌ Error initializing AdManager: $error');
      print('MapSubscriptionEn : Stack trace: ${StackTrace.current}');
    });

    print('MapSubscriptionEn : ✅ initState completed');
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
      print('MapSubscriptionEn : サブスクリプション状態確認完了-isActive: $isActive');
    } catch (e) {
      print('MapSubscriptionEn : サブスクリプション状態確認エラー: $e');

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
    print('=== MapSubscriptionEn Debug Info ===');
    print('_isAdAvailable: $_isAdAvailable');
    print('_searchLimitReached: $_searchLimitReached');
    print('_searchesRemaining: $_searchesRemaining');
    print('_isWatchingAd: $_isWatchingAd');
    print('AdManager debug info: ${AdManager.getDebugInfo()}');
    print('================================');
  }

  // 広告ステータス変更リスナーを修正（デバッグ強化）
  void _onAdStatusChanged(bool available) {
    print('MapSubscriptionEn : 📢 Ad status changed to: $available');
    print('MapSubscriptionEn : Widget mounted: $mounted');
    print(
        'MapSubscriptionEn : Current searchLimitReached: $_searchLimitReached');

    // ウィジェットがまだマウントされているかチェック
    if (!mounted) {
      print('MapSubscriptionEn : ⚠️ Widget not mounted, skipping setState');
      return;
    }

    // ウィジェットの状態が有効かチェック
    try {
      setState(() {
        _isAdAvailable = available;
        print(
            'MapSubscriptionEn : ✅ Ad availability updated to $_isAdAvailable');
      });

      // デバッグ情報を出力
      _printDebugInfo();
    } catch (e) {
      print('MapSubscriptionEn : ❌ Error updating ad status: $e');
      print('MapSubscriptionEn : Stack trace: ${StackTrace.current}');
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
    print('_userId: $_userId');
    // ユーザーの初期化を待つ
    if (_userId == null || _userId.isEmpty) {
      await _getUser();
    }

    try {
      // 現在のユーザーの検索使用状況ドキュメントを取得
      DocumentSnapshot searchUsageDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
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
          // 新しい日なら、検索カウントをリセット
          setState(() {
            _searchesRemaining = 3;
            _searchLimitReached = false;
            _lastSearchDate = DateTime.now();
          });

          // リセットした値でFirestoreを更新
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_userId)
              .collection('search_usage')
              .doc('daily_limit')
              .set({
            'searchCount': 0,
            'lastSearchDate': Timestamp.now(),
          });
        } else {
          // 同じ日なら、既存の検索カウントを使用
          setState(() {
            _searchesRemaining = 3 - searchCount;
            _searchLimitReached = _searchesRemaining <= 0;
            print(
                '新しい状態：searchesRemaining= $_searchesRemaining, limitReached=$_searchLimitReached');
            _lastSearchDate = DateTime.now();
          });
        }
      } else {
        // ドキュメントが存在しない場合、デフォルト値で作成
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('search_usage')
            .doc('daily_limit')
            .set({
          'searchCount': 0,
          'lastSearchDate': Timestamp.now(),
        });

        setState(() {
          _searchesRemaining = 3;
          _searchLimitReached = false;
        });
      }
    } catch (e) {
      print('Error loading search limit data: $e');
      // エラーの場合はデフォルト値を設定
      setState(() {
        _searchesRemaining = 3;
        _searchLimitReached = false;
      });
    }
  }

  // 検索カウントをFirestoreでインクリメントする新しいメソッド
  Future<void> _incrementSearchCount() async {
    try {
      // 現在のドキュメントを取得
      DocumentSnapshot searchUsageDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('search_usage')
          .doc('daily_limit')
          .get();

      if (searchUsageDoc.exists) {
        Map<String, dynamic> data =
            searchUsageDoc.data() as Map<String, dynamic>;
        int currentCount = data['searchCount'] ?? 0;
        DateTime lastSearchDate =
            (data['lastSearchDate'] as Timestamp).toDate();

        // 新しい日かチェック
        bool isNewDay = DateTime.now().day != lastSearchDate.day ||
            DateTime.now().month != lastSearchDate.month ||
            DateTime.now().year != lastSearchDate.year;

        if (isNewDay) {
          // 新しい日なら、カウントを1にリセット（この検索）
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_userId)
              .collection('search_usage')
              .doc('daily_limit')
              .set({
            'searchCount': 1,
            'lastSearchDate': Timestamp.now(),
          });

          setState(() {
            _searchesRemaining = 2; // 合計3回 - 使用済み1回
            _searchLimitReached = false;
            _lastSearchDate = DateTime.now();
          });
        } else {
          // 同じ日なら、カウントをインクリメント
          int newCount = currentCount + 1;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_userId)
              .collection('search_usage')
              .doc('daily_limit')
              .update({
            'searchCount': newCount,
            'lastSearchDate': Timestamp.now(),
          });

          setState(() {
            _searchesRemaining = 3 - newCount;
            _searchLimitReached = _searchesRemaining < 0;
            _lastSearchDate = DateTime.now();
          });

          if (_searchLimitReached) {
            print(
                'MapSubscriptionEn : 🚫Search limit reached! Clearing search and showing ad interface');
            _searchController.clear();
            _searchFocusNode.unfocus();

            setState(() {
              _searchResults = [];
              _isSearching = false;
            });

            if (_isAdAvailable && !_isWatchingAd) {
              print(
                  'MapSubscriptionEn : 📺 Ad available, showing reward dialog');
              _showSearchLimitReachedDialog();
            } else {
              print(
                  'MapSubscriptionEn : ⚠️ Ad not available, showing limit message');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white,
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: Text('今日の検索上限に達しました。明日また試してください。'),
                      ),
                    ],
                  ),
                  duration: Duration(seconds: 4),
                  backgroundColor: Colors.red[600],
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      } else {
        // ドキュメントが存在しない場合、count = 1で作成
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('search_usage')
            .doc('daily_limit')
            .set({
          'searchCount': 1,
          'lastSearchDate': Timestamp.now(),
        });

        setState(() {
          _searchesRemaining = 2; // 合計3回 - 使用済み1回
          _searchLimitReached = false;
        });
      }

      // 検索上限に達した場合、メッセージを表示
      if (_searchLimitReached) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('今日の検索上限に達しました。明日また試してください。'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error incrementing search count: $e');
    }
  }

  void _showSearchLimitReachedDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // ユーザーが外側をタップしても閉じないようにする
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // アイコン
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  color: Colors.red[600],
                  size: 48,
                ),
              ),
              SizedBox(height: 20),

              // タイトル
              Text(
                '検索制限に達しました',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),

              // 説明文
              Text(
                '今日の検索回数（3回）を使い切りました。\n広告を視聴して検索回数を追加するか、\n明日まで待つことができます。',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),

              // ボタン
              Column(
                children: [
                  // 広告視聴ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isAdAvailable && !_isWatchingAd
                          ? () {
                              Navigator.of(context).pop(); // ダイアログを閉じる
                              _showRewardedAd(); // 広告を表示
                            }
                          : null,
                      icon: Icon(
                        _isWatchingAd
                            ? Icons.hourglass_empty_rounded
                            : _isAdAvailable
                                ? Icons.play_circle_filled_rounded
                                : Icons.hourglass_empty_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _isWatchingAd
                            ? '広告読み込み中...'
                            : _isAdAvailable
                                ? '広告を視聴して検索回数を追加'
                                : '広告を準備中...',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAdAvailable && !_isWatchingAd
                            ? Colors.amber[600]
                            : Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _isAdAvailable && !_isWatchingAd ? 3 : 0,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),

                  // 後で試すボタン
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // ダイアログを閉じる
                      },
                      child: Text(
                        '後で試す',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[400]!),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

// 広告視聴後に検索上限をリセットするメソッド
  Future<void> _resetSearchLimitAfterAd() async {
    print('MapSubscriptionEn : 🎁 Starting search limit reset after ad...');

    // mountedチェックを追加
    if (!mounted) {
      print('MapSubscriptionEn : ⚠️ Widget not mounted, skipping reset');
      return;
    }

    try {
      print('MapSubscriptionEn : 💾 Updating Firestore search usage...');

      // Firestoreの検索上限をリセット
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('search_usage')
          .doc('daily_limit')
          .set({
        'searchCount': 0,
        'lastSearchDate': Timestamp.now(),
      });

      print('MapSubscriptionEn : ✅ Firestore search limit reset successful');

      // 状態を安全に更新
      if (mounted) {
        try {
          setState(() {
            _searchesRemaining = 3;
            _searchLimitReached = false;
            _lastSearchDate = DateTime.now();
            _isWatchingAd = false;
            print('MapSubscriptionEn : ✅ Local state updated after ad reward');
          });

          _printDebugInfo();
        } catch (e) {
          print('MapSubscriptionEn : ❌ Error updating state after ad: $e');
          print('MapSubscriptionEn : Stack trace: ${StackTrace.current}');
          return;
        }
      }

      // 成功メッセージを表示（mountedチェック付き）
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('検索制限がリセットされました。'),
                ),
              ],
            ),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('MapSubscriptionEn : ❌ Error resetting search limit: $e');
      print('MapSubscriptionEn : Stack trace: ${StackTrace.current}');

      if (mounted) {
        try {
          setState(() {
            _isWatchingAd = false;
          });
        } catch (stateError) {
          print(
              'MapSubscriptionEn : ❌ Error updating state on error: $stateError');
        }

        // エラーメッセージを表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('検索制限のリセットに失敗しました。もう一度お試しください。'),
                ),
              ],
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 広告を表示するメソッドを修正（デバッグ強化）
  void _showRewardedAd() {
    print('MapSubscriptionEn : 🎬 Show rewarded ad button pressed');
    print('MapSubscriptionEn : Widget mounted: $mounted');

    _printDebugInfo();

    // mountedチェックを追加
    if (!mounted) {
      print('MapSubscriptionEn : ⚠️ Widget not mounted, skipping ad show');
      return;
    }

    // 最新の状態を再確認
    bool adAvailable = AdManager.isRewardedAdAvailable();
    print('MapSubscriptionEn : 🔍 Current ad availability: $adAvailable');

    if (!adAvailable) {
      print('MapSubscriptionEn : ❌ Ad not available, showing error message');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_outlined, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('広告の準備ができていません。しばらくしてからもう一度お試しください。'),
                ),
              ],
            ),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.orange[600],
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'デバッグ情報',
              textColor: Colors.white,
              onPressed: () {
                _printDebugInfo();
                _showDebugDialog();
              },
            ),
          ),
        );
      }

      // 広告の再読み込みを試みる
      print('MapSubscriptionEn : 🔄 Attempting to reload ad...');
      AdManager.reloadAd();
      return;
    }

    // 状態を安全に更新
    if (mounted) {
      try {
        setState(() {
          _isWatchingAd = true;
          print('MapSubscriptionEn : ✅ Set _isWatchingAd to true');
        });
      } catch (e) {
        print('MapSubscriptionEn : ❌ Error setting watching ad state: $e');
        return;
      }
    }

    print('MapSubscriptionEn : 🚀 Calling AdManager.showRewardedAd()...');

    // 広告を表示
    AdManager.showRewardedAd(() {
      print('MapSubscriptionEn : 🎁 Reward callback triggered!');
      _resetSearchLimitAfterAd();
    }).then((bool success) {
      print('MapSubscriptionEn : 📊 Ad show result: $success');

      if (!success && mounted) {
        print('MapSubscriptionEn : ❌ Ad show failed, resetting state');
        try {
          setState(() {
            _isWatchingAd = false;
          });
        } catch (e) {
          print(
              'MapSubscriptionEn : ❌ Error updating state after ad failure: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('広告の表示に失敗しました。もう一度お試しください。'),
                  ),
                ],
              ),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }).catchError((error) {
      print('MapSubscriptionEn : ❌ Error in showRewardedAd: $error');
      print('MapSubscriptionEn : Stack trace: ${StackTrace.current}');

      if (mounted) {
        try {
          setState(() {
            _isWatchingAd = false;
          });
        } catch (e) {
          print('MapSubscriptionEn : ❌ Error updating state on ad error: $e');
        }
      }
    });
  }

  // デバッグダイアログを表示するメソッド
  void _showDebugDialog() {
    if (!mounted) return;

    final debugInfo = AdManager.getDebugInfo();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('🐛 広告デバッグ情報'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MapSubscriptionEn 状態:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('• _isAdAvailable: $_isAdAvailable'),
                Text('• _searchLimitReached: $_searchLimitReached'),
                Text('• _searchesRemaining: $_searchesRemaining'),
                Text('• _isWatchingAd: $_isWatchingAd'),
                SizedBox(height: 16),
                Text('AdManager状態:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('• 初期化済み: ${debugInfo['isInitialized']}'),
                Text('• 広告ロード済み: ${debugInfo['isRewardedAdLoaded']}'),
                Text('• ロード中: ${debugInfo['isLoading']}'),
                Text('• 広告インスタンス存在: ${debugInfo['rewardedAdExists']}'),
                Text('• デバッグモード: ${debugInfo['debugMode']}'),
                Text('• リスナー数: ${debugInfo['listenersCount']}'),
                Text('• 広告ユニットID: ${debugInfo['adUnitId']}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _printDebugInfo();
              },
              child: Text('ログ出力'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                print(
                    'MapSubscriptionEn : 🔄 Manual ad reload requested from debug dialog');
                AdManager.reloadAd();
              },
              child: Text('広告再読み込み'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getUser() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    _user = auth.currentUser!;
    _userId = _user.uid;
  }

  //緯度と経度から住所を取得するヘルパー関数
  Future<String> _getAddressFromLatLng(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String prefecture = place.administrativeArea ?? '';
        String city = place.locality ?? '';

        if (prefecture.isNotEmpty || city.isNotEmpty) {
          return ' (${prefecture}${city.isNotEmpty ? ' $city' : ''})';
        }
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return '';
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorDialog('位置情報サービスが無効です。');
      setState(() {
        _isLoading = false;
        _errorOccurred = true;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationPermissionDialog(
          message: '位置情報の許可が必要です。',
          actionText: '設定を開く',
        );
        setState(() {
          _isLoading = false;
          _errorOccurred = true;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationPermissionDialog(
        message: '位置情報がオフになっています。設定アプリケーションで位置情報をオンにしてください。',
        actionText: '設定を開く',
      );
      setState(() {
        _isLoading = false;
        _errorOccurred = true;
      });
      return;
    }

    final Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _isLoading = false;
      _addCurrentLocationCircle();
    });
    _moveToCurrentLocation();
  }

  // 検索機能のメソッドを修正
  // 検索機能のメソッドを修正（緯度経度のみ使用）
  void _performSearch(String query) async {
    print('===検索実行前の状態==');
    print('_searchLimitReached: $_searchLimitReached');
    print('_searchesRemaining: $_searchesRemaining');
    print('_lastSearchDate: $_lastSearchDate');
    print('_isSubscriptionActive: $_isSubscriptionActive');
    print('query: $query');

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    // 検索の前に検索上限に達しているかチェック
    if (!_isSubscriptionActive && _searchLimitReached) {
      print('検索制限に引っかかりました');
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });

      _searchController.clear();
      _searchFocusNode.unfocus();

      if (_isAdAvailable && !_isWatchingAd) {
        _showSearchLimitReachedDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('今日の検索上限に達しました。\n明日また試してください。'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      List<DocumentSnapshot> allResults = [];

      // 1. タイトルで検索
      QuerySnapshot titleSnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(20)
          .get();

      allResults.addAll(titleSnapshot.docs);

      // 2. アニメ名で検索
      QuerySnapshot animeSnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .where('animeName', isGreaterThanOrEqualTo: query)
          .where('animeName', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(20)
          .get();

      allResults.addAll(animeSnapshot.docs);

      // 3. 全てのロケーションを取得して地理的検索を実行
      // 都道府県検索の場合、全データを取得して緯度経度から住所を判定
      if (_isPrefectureQuery(query)) {
        QuerySnapshot allLocationsSnapshot =
            await FirebaseFirestore.instance.collection('locations').get();

        allResults.addAll(allLocationsSnapshot.docs);
      }

      // 重複を除去
      Map<String, DocumentSnapshot> uniqueResults = {};
      for (var doc in allResults) {
        uniqueResults[doc.id] = doc;
      }

      // 地理的フィルタリングと住所マッチング
      List<DocumentSnapshot> filteredResults = [];

      for (var doc in uniqueResults.values) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // 基本的なフィールドマッチング
        bool matches = await _checkBasicMatch(data, query);

        // 都道府県検索の場合の地理的マッチング
        if (!matches && data['latitude'] != null && data['longitude'] != null) {
          matches = await _checkGeographicMatch(data, query);
        }

        if (matches) {
          filteredResults.add(doc);
        }
      }

      // 結果を最大15件に制限
      List<DocumentSnapshot> finalResults = filteredResults.take(15).toList();

      setState(() {
        _searchResults = finalResults;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching: $e');
      setState(() {
        _isSearching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('検索中にエラーが発生しました'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 都道府県クエリかどうかを判定するヘルパーメソッド
  // 都道府県クエリかどうかを判定するヘルパーメソッド（全47都道府県対応）
  bool _isPrefectureQuery(String query) {
    List<String> prefectures = [
      // 北海道
      '北海道', 'ほっかいどう', 'hokkaido',

      // 東北地方
      '青森', '青森県', 'あおもり', 'aomori',
      '岩手', '岩手県', 'いわて', 'iwate',
      '宮城', '宮城県', 'みやぎ', 'miyagi',
      '秋田', '秋田県', 'あきた', 'akita',
      '山形', '山形県', 'やまがた', 'yamagata',
      '福島', '福島県', 'ふくしま', 'fukushima',

      // 関東地方
      '茨城', '茨城県', 'いばらき', 'ibaraki',
      '栃木', '栃木県', 'とちぎ', 'tochigi',
      '群馬', '群馬県', 'ぐんま', 'gunma',
      '埼玉', '埼玉県', 'さいたま', 'saitama',
      '千葉', '千葉県', 'ちば', 'chiba',
      '東京', '東京都', 'とうきょう', 'tokyo',
      '神奈川', '神奈川県', 'かながわ', 'kanagawa',

      // 中部地方
      '新潟', '新潟県', 'にいがた', 'niigata',
      '富山', '富山県', 'とやま', 'toyama',
      '石川', '石川県', 'いしかわ', 'ishikawa',
      '福井', '福井県', 'ふくい', 'fukui',
      '山梨', '山梨県', 'やまなし', 'yamanashi',
      '長野', '長野県', 'ながの', 'nagano',
      '岐阜', '岐阜県', 'ぎふ', 'gifu',
      '静岡', '静岡県', 'しずおか', 'shizuoka',
      '愛知', '愛知県', 'あいち', 'aichi',

      // 近畿地方
      '三重', '三重県', 'みえ', 'mie',
      '滋賀', '滋賀県', 'しが', 'shiga',
      '京都', '京都府', 'きょうと', 'kyoto',
      '大阪', '大阪府', 'おおさか', 'osaka',
      '兵庫', '兵庫県', 'ひょうご', 'hyogo',
      '奈良', '奈良県', 'なら', 'nara',
      '和歌山', '和歌山県', 'わかやま', 'wakayama',

      // 中国地方
      '鳥取', '鳥取県', 'とっとり', 'tottori',
      '島根', '島根県', 'しまね', 'shimane',
      '岡山', '岡山県', 'おかやま', 'okayama',
      '広島', '広島県', 'ひろしま', 'hiroshima',
      '山口', '山口県', 'やまぐち', 'yamaguchi',

      // 四国地方
      '徳島', '徳島県', 'とくしま', 'tokushima',
      '香川', '香川県', 'かがわ', 'kagawa',
      '愛媛', '愛媛県', 'えひめ', 'ehime',
      '高知', '高知県', 'こうち', 'kochi',

      // 九州・沖縄地方
      '福岡', '福岡県', 'ふくおか', 'fukuoka',
      '佐賀', '佐賀県', 'さが', 'saga',
      '長崎', '長崎県', 'ながさき', 'nagasaki',
      '熊本', '熊本県', 'くまもと', 'kumamoto',
      '大分', '大分県', 'おおいた', 'oita',
      '宮崎', '宮崎県', 'みやざき', 'miyazaki',
      '鹿児島', '鹿児島県', 'かごしま', 'kagoshima',
      '沖縄', '沖縄県', 'おきなわ', 'okinawa',
    ];

    String queryLower = query.toLowerCase();
    for (String pref in prefectures) {
      if (pref.toLowerCase().contains(queryLower) ||
          queryLower.contains(pref.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  // 基本的なフィールドマッチングをチェック
  Future<bool> _checkBasicMatch(Map<String, dynamic> data, String query) async {
    String queryLower = query.toLowerCase();

    String title = (data['title'] ?? '').toString().toLowerCase();
    String animeName = (data['animeName'] ?? '').toString().toLowerCase();

    return title.contains(queryLower) || animeName.contains(queryLower);
  }

  // 地理的マッチング（緯度経度から住所を取得してマッチング）- エラーハンドリング強化版
  Future<bool> _checkGeographicMatch(
      Map<String, dynamic> data, String query) async {
    try {
      double latitude = (data['latitude'] as num).toDouble();
      double longitude = (data['longitude'] as num).toDouble();

      // まず座標範囲での簡易チェック（日本国内かどうか）
      if (!_isInJapan(latitude, longitude)) {
        return false;
      }

      // Geocodingを試行（タイムアウトとリトライ機能付き）
      List<Placemark>? placemarks =
          await _getPlacemarksWithRetry(latitude, longitude);

      if (placemarks != null && placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return _matchAddressWithQuery(place, query);
      } else {
        // Geocodingが失敗した場合、座標ベースの地域判定を使用
        return _matchByCoordinates(latitude, longitude, query);
      }
    } catch (e) {
      print('Error in geographic matching: $e');

      // エラーが発生した場合は座標ベースの判定にフォールバック
      try {
        double latitude = (data['latitude'] as num).toDouble();
        double longitude = (data['longitude'] as num).toDouble();
        return _matchByCoordinates(latitude, longitude, query);
      } catch (fallbackError) {
        print('Fallback coordinate matching also failed: $fallbackError');
        return false;
      }
    }
  }

  // 日本国内の座標かどうかを判定
  bool _isInJapan(double latitude, double longitude) {
    // 日本の大まかな座標範囲
    return latitude >= 24.0 &&
        latitude <= 46.0 &&
        longitude >= 123.0 &&
        longitude <= 146.0;
  }

// リトライ機能付きのGeocodingメソッド
  Future<List<Placemark>?> _getPlacemarksWithRetry(
      double latitude, double longitude,
      {int maxRetries = 2}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // タイムアウトを設定してGeocodingを実行
        List<Placemark> placemarks =
            await placemarkFromCoordinates(latitude, longitude)
                .timeout(Duration(seconds: 5));

        if (placemarks.isNotEmpty) {
          return placemarks;
        }
      } catch (e) {
        if (attempt < maxRetries - 1) {
          // 次の試行前に少し待機
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    }
    return null;
  }

  // 住所情報とクエリのマッチング
  bool _matchAddressWithQuery(Placemark place, String query) {
    // 取得した住所情報
    String country = (place.country ?? '').toLowerCase();
    String administrativeArea = (place.administrativeArea ?? '').toLowerCase();
    String locality = (place.locality ?? '').toLowerCase();
    String subLocality = (place.subLocality ?? '').toLowerCase();
    String thoroughfare = (place.thoroughfare ?? '').toLowerCase();

    String queryLower = query.toLowerCase();

    // 都道府県マッチング
    if (_matchesPrefecture(administrativeArea, queryLower)) {
      return true;
    }

    // 市区町村マッチング
    if (locality.contains(queryLower) ||
        subLocality.contains(queryLower) ||
        thoroughfare.contains(queryLower)) {
      return true;
    }

    // 都道府県の別名マッチング
    if (_matchesPrefectureAlias(administrativeArea, queryLower)) {
      return true;
    }

    return false;
  }

// 座標ベースの地域判定（Geocodingの代替手段）
  bool _matchByCoordinates(double latitude, double longitude, String query) {
    String queryLower = query.toLowerCase();

    // 主要都道府県の大まかな座標範囲
    Map<String, Map<String, double>> prefectureBounds = {
      '北海道': {'minLat': 41.4, 'maxLat': 45.5, 'minLng': 139.4, 'maxLng': 148.9},
      '青森': {'minLat': 40.2, 'maxLat': 41.6, 'minLng': 139.5, 'maxLng': 141.7},
      '岩手': {'minLat': 38.7, 'maxLat': 40.4, 'minLng': 140.7, 'maxLng': 142.1},
      '宮城': {'minLat': 37.8, 'maxLat': 39.0, 'minLng': 140.3, 'maxLng': 141.7},
      '秋田': {'minLat': 38.9, 'maxLat': 40.6, 'minLng': 139.5, 'maxLng': 141.2},
      '山形': {'minLat': 37.7, 'maxLat': 39.0, 'minLng': 139.3, 'maxLng': 140.6},
      '福島': {'minLat': 36.8, 'maxLat': 37.9, 'minLng': 139.3, 'maxLng': 141.1},
      '茨城': {'minLat': 35.7, 'maxLat': 36.9, 'minLng': 139.7, 'maxLng': 140.9},
      '栃木': {'minLat': 36.2, 'maxLat': 37.0, 'minLng': 139.4, 'maxLng': 140.3},
      '群馬': {'minLat': 36.0, 'maxLat': 36.9, 'minLng': 138.4, 'maxLng': 139.9},
      '埼玉': {'minLat': 35.7, 'maxLat': 36.3, 'minLng': 138.7, 'maxLng': 139.9},
      '千葉': {'minLat': 34.9, 'maxLat': 36.1, 'minLng': 139.7, 'maxLng': 140.9},
      '東京': {
        'minLat': 35.5,
        'maxLat': 35.9,
        'minLng': 136.1,
        'maxLng': 153.9
      }, // 島嶼部含む
      '神奈川': {'minLat': 35.1, 'maxLat': 35.6, 'minLng': 138.9, 'maxLng': 139.8},
      '新潟': {'minLat': 37.0, 'maxLat': 38.6, 'minLng': 137.6, 'maxLng': 139.9},
      '富山': {'minLat': 36.3, 'maxLat': 36.9, 'minLng': 136.8, 'maxLng': 137.9},
      '石川': {'minLat': 36.0, 'maxLat': 37.6, 'minLng': 135.8, 'maxLng': 137.4},
      '福井': {'minLat': 35.3, 'maxLat': 36.4, 'minLng': 135.4, 'maxLng': 136.7},
      '山梨': {'minLat': 35.1, 'maxLat': 35.9, 'minLng': 138.2, 'maxLng': 139.2},
      '長野': {'minLat': 35.2, 'maxLat': 37.0, 'minLng': 137.3, 'maxLng': 138.9},
      '岐阜': {'minLat': 35.3, 'maxLat': 36.4, 'minLng': 136.0, 'maxLng': 137.9},
      '静岡': {'minLat': 34.6, 'maxLat': 35.4, 'minLng': 137.5, 'maxLng': 139.2},
      '愛知': {'minLat': 34.6, 'maxLat': 35.4, 'minLng': 136.7, 'maxLng': 137.8},
      '三重': {'minLat': 33.7, 'maxLat': 35.2, 'minLng': 135.9, 'maxLng': 137.1},
      '滋賀': {'minLat': 34.8, 'maxLat': 35.7, 'minLng': 135.7, 'maxLng': 136.5},
      '京都': {'minLat': 34.7, 'maxLat': 35.8, 'minLng': 135.0, 'maxLng': 136.0},
      '大阪': {'minLat': 34.3, 'maxLat': 34.8, 'minLng': 135.1, 'maxLng': 135.8},
      '兵庫': {'minLat': 34.3, 'maxLat': 35.7, 'minLng': 134.2, 'maxLng': 135.5},
      '奈良': {'minLat': 33.8, 'maxLat': 34.8, 'minLng': 135.6, 'maxLng': 136.1},
      '和歌山': {'minLat': 33.4, 'maxLat': 34.4, 'minLng': 135.1, 'maxLng': 135.8},
      '鳥取': {'minLat': 35.0, 'maxLat': 35.6, 'minLng': 133.3, 'maxLng': 134.4},
      '島根': {'minLat': 34.1, 'maxLat': 35.8, 'minLng': 131.7, 'maxLng': 133.5},
      '岡山': {'minLat': 34.3, 'maxLat': 35.4, 'minLng': 133.3, 'maxLng': 134.7},
      '広島': {'minLat': 34.0, 'maxLat': 34.9, 'minLng': 132.0, 'maxLng': 133.3},
      '山口': {'minLat': 33.7, 'maxLat': 34.6, 'minLng': 130.8, 'maxLng': 132.3},
      '徳島': {'minLat': 33.7, 'maxLat': 34.4, 'minLng': 133.5, 'maxLng': 134.8},
      '香川': {'minLat': 34.1, 'maxLat': 34.5, 'minLng': 133.3, 'maxLng': 134.5},
      '愛媛': {'minLat': 32.8, 'maxLat': 34.4, 'minLng': 132.3, 'maxLng': 133.9},
      '高知': {'minLat': 32.7, 'maxLat': 34.0, 'minLng': 132.5, 'maxLng': 134.3},
      '福岡': {'minLat': 33.0, 'maxLat': 34.0, 'minLng': 129.7, 'maxLng': 131.3},
      '佐賀': {'minLat': 33.0, 'maxLat': 33.5, 'minLng': 129.7, 'maxLng': 130.4},
      '長崎': {'minLat': 32.6, 'maxLat': 34.7, 'minLng': 128.8, 'maxLng': 130.4},
      '熊本': {'minLat': 32.2, 'maxLat': 33.3, 'minLng': 130.2, 'maxLng': 131.3},
      '大分': {'minLat': 32.8, 'maxLat': 33.6, 'minLng': 130.8, 'maxLng': 132.0},
      '宮崎': {'minLat': 31.4, 'maxLat': 32.8, 'minLng': 130.7, 'maxLng': 131.9},
      '鹿児島': {'minLat': 24.4, 'maxLat': 32.0, 'minLng': 128.9, 'maxLng': 131.0},
      '沖縄': {'minLat': 24.0, 'maxLat': 26.9, 'minLng': 122.9, 'maxLng': 131.3},
    };

    // クエリに対応する都道府県の座標範囲をチェック
    for (String prefName in prefectureBounds.keys) {
      List<String> searchTerms = [
        prefName,
        prefName + '県',
        prefName + '府',
        prefName + '都',
      ];

      // ひらがな・ローマ字の別名も追加
      Map<String, List<String>> aliases = _getPrefectureAliases();
      String fullPrefName = prefName +
          (prefName == '東京'
              ? '都'
              : prefName == '大阪' || prefName == '京都'
                  ? '府'
                  : prefName == '北海道'
                      ? ''
                      : '県');
      if (aliases.containsKey(fullPrefName)) {
        searchTerms.addAll(aliases[fullPrefName]!);
      }

      // いずれかの検索語と一致するかチェック
      bool matches = false;
      for (String term in searchTerms) {
        if (term.toLowerCase().contains(queryLower) ||
            queryLower.contains(term.toLowerCase())) {
          matches = true;
          break;
        }
      }

      if (matches) {
        // 座標がこの都道府県の範囲内かチェック
        Map<String, double> bounds = prefectureBounds[prefName]!;
        if (latitude >= bounds['minLat']! &&
            latitude <= bounds['maxLat']! &&
            longitude >= bounds['minLng']! &&
            longitude <= bounds['maxLng']!) {
          return true;
        }
      }
    }

    return false;
  }

// 都道府県の別名マップを取得
  Map<String, List<String>> _getPrefectureAliases() {
    return {
      '東京都': ['東京', 'とうきょう', 'tokyo'],
      '大阪府': ['大阪', 'おおさか', 'osaka'],
      '京都府': ['京都', 'きょうと', 'kyoto'],
      '北海道': ['ほっかいどう', 'hokkaido'],
      '沖縄県': ['沖縄', 'おきなわ', 'okinawa'],
      '神奈川県': ['神奈川', 'かながわ', 'kanagawa'],
      '千葉県': ['千葉', 'ちば', 'chiba'],
      '埼玉県': ['埼玉', 'さいたま', 'saitama'],
      '愛知県': ['愛知', 'あいち', 'aichi'],
      '兵庫県': ['兵庫', 'ひょうご', 'hyogo'],
      '福岡県': ['福岡', 'ふくおか', 'fukuoka'],
      '静岡県': ['静岡', 'しずおか', 'shizuoka'],
      '広島県': ['広島', 'ひろしま', 'hiroshima'],
      '宮城県': ['宮城', 'みやぎ', 'miyagi'],
      '新潟県': ['新潟', 'にいがた', 'niigata'],
      '長野県': ['長野', 'ながの', 'nagano'],
      '岐阜県': ['岐阜', 'ぎふ', 'gifu'],
      '三重県': ['三重', 'みえ', 'mie'],
      '滋賀県': ['滋賀', 'しが', 'shiga'],
      '奈良県': ['奈良', 'なら', 'nara'],
      '和歌山県': ['和歌山', 'わかやま', 'wakayama'],
      '岡山県': ['岡山', 'おかやま', 'okayama'],
      '山口県': ['山口', 'やまぐち', 'yamaguchi'],
      '愛媛県': ['愛媛', 'えひめ', 'ehime'],
      '高知県': ['高知', 'こうち', 'kochi'],
      '熊本県': ['熊本', 'くまもと', 'kumamoto'],
      '鹿児島県': ['鹿児島', 'かごしま', 'kagoshima'],
      // 他の都道府県も必要に応じて追加
    };
  }

// 住所情報を取得して表示するための補助メソッドを更新（エラーハンドリング強化）
  Future<String> _getLocationDisplayText(Map<String, dynamic> data) async {
    if (data['latitude'] != null && data['longitude'] != null) {
      double latitude = (data['latitude'] as num).toDouble();
      double longitude = (data['longitude'] as num).toDouble();

      try {
        // リトライ機能付きでGeocodingを試行
        List<Placemark>? placemarks =
            await _getPlacemarksWithRetry(latitude, longitude);

        if (placemarks != null && placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          String prefecture = place.administrativeArea ?? '';
          String city = place.locality ?? '';
          String subLocality = place.subLocality ?? '';

          String locationText = '';
          if (prefecture.isNotEmpty) locationText += prefecture;
          if (city.isNotEmpty && city != prefecture) {
            if (locationText.isNotEmpty) locationText += ' ';
            locationText += city;
          }
          if (subLocality.isNotEmpty && subLocality != city) {
            if (locationText.isNotEmpty) locationText += ' ';
            locationText += subLocality;
          }

          return locationText.isNotEmpty ? ' ($locationText)' : '';
        } else {
          // Geocodingが失敗した場合、座標ベースで大まかな地域を表示
          String region = _getRegionByCoordinates(latitude, longitude);
          return region.isNotEmpty ? ' ($region)' : '';
        }
      } catch (e) {
        print('Error getting address: $e');
        // エラーの場合も座標ベースで地域を表示
        String region = _getRegionByCoordinates(latitude, longitude);
        return region.isNotEmpty ? ' ($region)' : '';
      }
    }
    return '';
  }

// 座標から大まかな地域を取得
  String _getRegionByCoordinates(double latitude, double longitude) {
    if (latitude >= 35.5 &&
        latitude <= 35.9 &&
        longitude >= 139.3 &&
        longitude <= 139.9) {
      return '東京都周辺';
    } else if (latitude >= 34.3 &&
        latitude <= 34.8 &&
        longitude >= 135.1 &&
        longitude <= 135.8) {
      return '大阪府周辺';
    } else if (latitude >= 41.4 &&
        latitude <= 45.5 &&
        longitude >= 139.4 &&
        longitude <= 148.9) {
      return '北海道';
    } else if (latitude >= 33.0 && latitude <= 36.0) {
      return '関西・中国・四国地方';
    } else if (latitude >= 36.0 && latitude <= 41.0) {
      return '関東・中部・東北地方';
    } else if (latitude >= 31.0 && latitude <= 34.0) {
      return '九州地方';
    } else if (latitude >= 24.0 && latitude <= 27.0) {
      return '沖縄県';
    }
    return '日本';
  }

// 都道府県の直接マッチング
  bool _matchesPrefecture(String administrativeArea, String query) {
    return administrativeArea.contains(query) ||
        query.contains(administrativeArea);
  }

// 都道府県の別名マッチング
  bool _matchesPrefectureAlias(String administrativeArea, String query) {
    Map<String, List<String>> prefectureAliases = {
      '東京都': ['東京', 'とうきょう', 'tokyo'],
      '大阪府': ['大阪', 'おおさか', 'osaka'],
      '京都府': ['京都', 'きょうと', 'kyoto'],
      '北海道': ['ほっかいどう', 'hokkaido'],
      '沖縄県': ['沖縄', 'おきなわ', 'okinawa'],
      '神奈川県': ['神奈川', 'かながわ', 'kanagawa'],
      '千葉県': ['千葉', 'ちば', 'chiba'],
      '埼玉県': ['埼玉', 'さいたま', 'saitama'],
      '愛知県': ['愛知', 'あいち', 'aichi'],
      '兵庫県': ['兵庫', 'ひょうご', 'hyogo'],
      '福岡県': ['福岡', 'ふくおか', 'fukuoka'],
      '静岡県': ['静岡', 'しずおか', 'shizuoka'],
      '広島県': ['広島', 'ひろしま', 'hiroshima'],
      '宮城県': ['宮城', 'みやぎ', 'miyagi'],
      '新潟県': ['新潟', 'にいがた', 'niigata'],
      '長野県': ['長野', 'ながの', 'nagano'],
      '岐阜県': ['岐阜', 'ぎふ', 'gifu'],
      '三重県': ['三重', 'みえ', 'mie'],
      '滋賀県': ['滋賀', 'しが', 'shiga'],
      '奈良県': ['奈良', 'なら', 'nara'],
      '和歌山県': ['和歌山', 'わかやま', 'wakayama'],
      '岡山県': ['岡山', 'おかやま', 'okayama'],
      '山口県': ['山口', 'やまぐち', 'yamaguchi'],
      '愛媛県': ['愛媛', 'えひめ', 'ehime'],
      '高知県': ['高知', 'こうち', 'kochi'],
      '熊本県': ['熊本', 'くまもと', 'kumamoto'],
      '鹿児島県': ['鹿児島', 'かごしま', 'kagoshima'],
      // 必要に応じて他の都道府県も追加
    };

    for (String pref in prefectureAliases.keys) {
      if (administrativeArea.contains(pref.toLowerCase())) {
        List<String> aliases = prefectureAliases[pref]!;
        for (String alias in aliases) {
          if (alias.toLowerCase().contains(query) ||
              query.contains(alias.toLowerCase())) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // 検索使用状況を追跡するように_jumpToLocationメソッドを修正
  void _jumpToLocation(DocumentSnapshot locationDoc) async {
    // 検索上限に達しているかチェック
    if (!_isSubscriptionActive && _searchLimitReached) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('今日の検索上限に達しました。明日また試してください。'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
      return; // 上限に達していたら処理を中止
    }

    if (!_isSubscriptionActive) {
      // 検索カウントをインクリメント
      await _incrementSearchCount();

      // インクリメントによって上限に達した場合、処理を中止
      if (_searchLimitReached) {
        return;
      }
    }

    // 元の_jumpToLocationコードの続き
    Map<String, dynamic> data = locationDoc.data() as Map<String, dynamic>;
    double latitude = (data['latitude'] as num).toDouble();
    double longitude = (data['longitude'] as num).toDouble();
    LatLng position = LatLng(latitude, longitude);
    String locationId = locationDoc.id;

    // 変数をここで先に初期化
    String imageUrl = data['imageUrl'] ?? '';
    String title = data['title'] ?? '';
    String animeName = data['animeName'] ?? '';
    String description = data['description'] ?? '';

    // 検索をクリア
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
    });

    // マーカーがすでに表示されているか確認
    bool markerExists =
        _markers.any((marker) => marker.markerId.value == locationId);

    if (!markerExists) {
      // マーカーが存在しない場合は新しく作成
      Marker? newMarker = await _createMarkerWithImage(
        position,
        imageUrl,
        locationId,
        300,
        200,
        title,
        animeName,
        description,
      );

      if (newMarker != null) {
        setState(() {
          _markers.add(newMarker);
          _selectedMarker = newMarker;
        });
      }
    } else {
      // すでに存在する場合は選択状態にする
      setState(() {
        _selectedMarker = _markers
            .firstWhere((marker) => marker.markerId.value == locationId);
      });
    }

    // カメラを位置に移動
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 17.0,
        ),
      ),
    );

    // 強調表示するサークルを作成
    Circle highlightCircle = Circle(
      circleId: CircleId('highlight_$locationId'),
      center: position,
      radius: 50,
      fillColor: Colors.blue.withOpacity(0.3),
      strokeColor: Colors.blue,
      strokeWidth: 2,
    );

    setState(() {
      _circles.add(highlightCircle);
    });

    // 数秒後に強調表示サークルを削除
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _circles.removeWhere(
              (circle) => circle.circleId.value == 'highlight_$locationId');
        });
      }
    });

    // 距離計算を行い、チェックイン可能か確認
    _calculateDistance(position);

    // 少し遅延を入れて、マーカーの詳細情報を表示（オプション）
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted && _selectedMarker != null) {
        // チェックイン状態を確認
        _hasCheckedIn(locationId).then((hasCheckedIn) {
          // マーカーの詳細ボトムシートを表示
          _showModalBottomSheet(
            context,
            imageUrl,
            title,
            animeName,
            description,
            hasCheckedIn,
          );
        });
      }
    });
  }

  Widget _buildSearchBar() {
    print(
        'MapSubscriptionEn : Building search bar - searchLimitReached: $_searchLimitReached, searchesRemaining: $_searchesRemaining');

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 15,
      right: 15,
      child: Container(
        decoration: BoxDecoration(
          // グラデーション背景を追加
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.98),
              Colors.white.withOpacity(0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            // より深い影効果
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
              offset: Offset(0, 5),
            ),
            // 内側の光効果
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 5,
              spreadRadius: -2,
              offset: Offset(0, -2),
            ),
          ],
          border: Border.all(
            color: Colors.blue.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                  decoration: InputDecoration(
                    hintText: _isSubscriptionActive
                        ? 'スポットまたはアニメ名を検索）'
                        : _searchLimitReached
                            ? '本日の検索上限に達しました'
                            : 'スポットまたはアニメ名を検索 (残り$_searchesRemaining回)',
                    hintStyle: TextStyle(
                      color: _searchLimitReached
                          ? Colors.red[400]
                          : Colors.grey[500],
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                    ),
                    prefixIcon: Container(
                      padding: EdgeInsets.all(12),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        child: Icon(
                          Icons.search_rounded,
                          color: _searchLimitReached
                              ? Colors.red[400]
                              : _searchFocusNode.hasFocus
                                  ? Color(0xFF00008b)
                                  : Colors.grey[600],
                          size: 24,
                        ),
                      ),
                    ),
                    suffixIcon: _buildSuffixIcon(),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onChanged: (value) {
                    print('MapSubscriptionEn : Search text changed: "$value"');
                    _performSearch(value);
                  },
                  enabled: _isSubscriptionActive || !_searchLimitReached,
                ),
              ),
            ),

            if (_isSubscriptionActive)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber[300]!, Colors.orange[400]!],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'プレミアム会員 ー 検索制限なし',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  ],
                ),
              ),

            // アニメーション付きプログレスバー
            AnimatedContainer(
              duration: Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              height: _isSearching || _isWatchingAd ? 3 : 0,
              child: _isWatchingAd
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber[300]!,
                            Colors.amber[700]!,
                            Colors.amber[300]!,
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.transparent),
                      ),
                    )
                  : _isSearching
                      ? Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF00008b).withOpacity(0.3),
                                Color(0xFF00008b),
                                Color(0xFF00008b).withOpacity(0.3),
                              ],
                              stops: [0.0, 0.5, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.transparent),
                          ),
                        )
                      : null,
            ),

            // 検索制限メッセージ（改良版）
            if (!_isSubscriptionActive &&
                _searchLimitReached &&
                _searchResults.isEmpty)
              _buildLimitReachedCard(),

            // 検索結果（改良版）
            if (_searchResults.isNotEmpty) _buildSearchResults(),
          ],
        ),
      ),
    );
  }

// MapSubscriptionEn クラスの _buildSuffixIcon メソッドを以下に置き換えてください

  Widget _buildSuffixIcon() {
    print(
        'MapSubscriptionEn : Building suffix icon - searchLimitReached: $_searchLimitReached, isAdAvailable: $_isAdAvailable, isWatchingAd: $_isWatchingAd');

    if (_searchController.text.isNotEmpty) {
      return Container(
        padding: EdgeInsets.all(8),
        child: AnimatedScale(
          scale: _searchController.text.isNotEmpty ? 1.0 : 0.0,
          duration: Duration(milliseconds: 200),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                print('MapSubscriptionEn : Clear button tapped');
                _searchController.clear();
                setState(() {
                  _searchResults = [];
                });
                FocusScope.of(context).unfocus();
              },
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.clear_rounded,
                  color: Colors.grey[600],
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      );
    } else if (_searchLimitReached) {
      print('MapSubscriptionEn : Search limit reached, showing ad button');
      return Container(
        padding: EdgeInsets.all(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              print('MapSubscriptionEn : 🎬 Search bar ad button tapped!');
              print(
                  'MapSubscriptionEn : isWatchingAd: $_isWatchingAd, isAdAvailable: $_isAdAvailable');

              if (_isWatchingAd) {
                print('MapSubscriptionEn : Already watching ad, ignoring tap');
                return;
              }

              if (!_isAdAvailable) {
                print('MapSubscriptionEn : Ad not available from search bar');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.warning_outlined, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('広告の準備ができていません。しばらくしてからもう一度お試しください。'),
                        ),
                      ],
                    ),
                    duration: Duration(seconds: 3),
                    backgroundColor: Colors.orange[600],
                    behavior: SnackBarBehavior.floating,
                  ),
                );

                // 広告の再読み込みを試みる
                AdManager.reloadAd();
                return;
              }

              // 広告を表示
              print(
                  'MapSubscriptionEn : Calling _showRewardedAd from search bar');
              _showRewardedAd();
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _isAdAvailable && !_isWatchingAd
                    ? LinearGradient(
                        colors: [Colors.amber[300]!, Colors.amber[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color:
                    _isAdAvailable && !_isWatchingAd ? null : Colors.grey[300],
                shape: BoxShape.circle,
                boxShadow: _isAdAvailable && !_isWatchingAd
                    ? [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _isWatchingAd
                    ? Icons.hourglass_empty_rounded
                    : _isAdAvailable
                        ? Icons.play_circle_filled_rounded
                        : Icons.hourglass_empty_rounded,
                color: _isAdAvailable && !_isWatchingAd
                    ? Colors.white
                    : Colors.grey[600],
                size: 22,
              ),
            ),
          ),
        ),
      );
    }

    print('MapSubscriptionEn : No suffix icon needed');
    return SizedBox.shrink();
  }

// 検索制限カードの構築
  // 検索制限カードの構築（デバッグボタン付き）
  Widget _buildLimitReachedCard() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.withOpacity(0.1),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Colors.red[600],
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isWatchingAd ? '広告を読み込み中...' : '検索制限に達しました',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!_isWatchingAd)
                      Text(
                        '広告を視聴して検索回数を追加するか、翌日までお待ちください。',
                        style: TextStyle(
                          color: Colors.red[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              // デバッグボタンを追加
              if (kDebugMode)
                IconButton(
                  icon:
                      Icon(Icons.bug_report, color: Colors.grey[600], size: 20),
                  onPressed: _showDebugDialog,
                  tooltip: 'デバッグ情報',
                ),
            ],
          ),

          // 広告視聴ボタンを追加
          if (!_isWatchingAd && _searchLimitReached)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isAdAvailable ? _showRewardedAd : null,
                      icon: Icon(
                        _isAdAvailable
                            ? Icons.play_circle_filled
                            : Icons.hourglass_empty,
                        size: 20,
                      ),
                      label: Text(
                        _isAdAvailable ? '広告を視聴して検索回数を追加' : '広告を準備中...',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAdAvailable
                            ? Colors.amber[600]
                            : Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _isAdAvailable ? 3 : 0,
                      ),
                    ),
                  ),
                  // デバッグモードでは追加のテストボタンを表示
                  if (kDebugMode) ...[
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        print('MapSubscriptionEn : 🧪 Debug: Force reload ad');
                        AdManager.reloadAd();
                      },
                      child: Text('🔄', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.all(12),
                        shape: CircleBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

// 検索結果の構築
  Widget _buildSearchResults() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait(_searchResults.map((doc) async {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String locationInfo = '';

        if (data['latitude'] != null && data['longitude'] != null) {
          double latitude = (data['latitude'] as num).toDouble();
          double longitude = (data['longitude'] as num).toDouble();
          locationInfo = await _getAddressFromLatLng(latitude, longitude);
        }

        return {
          ...data,
          'locationInfo': locationInfo,
          'doc': doc,
        };
      }).toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 120,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF00008b)),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '検索中...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: 100,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    color: Colors.grey[400],
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '検索結果がありません',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final searchResultsWithAddress = snapshot.data!;

        return AnimatedContainer(
          duration: Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          constraints: BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              itemCount: searchResultsWithAddress.length,
              separatorBuilder: (context, index) => Container(
                height: 1,
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.grey.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              itemBuilder: (context, index) {
                final data = searchResultsWithAddress[index];
                final doc = data['doc'] as DocumentSnapshot;
                final locationInfo = data['locationInfo'] as String;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _jumpToLocation(doc),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50],
                      ),
                      child: Row(
                        children: [
                          // 画像アバター（改良版）
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: data['imageUrl'] != null &&
                                      data['imageUrl'].toString().isNotEmpty
                                  ? Stack(
                                      children: [
                                        Image.network(
                                          data['imageUrl'],
                                          fit: BoxFit.cover,
                                          width: 56,
                                          height: 56,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return _buildFallbackAvatar();
                                          },
                                        ),
                                        // オーバーレイエフェクト
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.1),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : _buildFallbackAvatar(),
                            ),
                          ),
                          SizedBox(width: 16),

                          // テキスト情報
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (data['title'] ?? 'No Title') + locationInfo,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.grey[800],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (data['animeName'] != null &&
                                    data['animeName']
                                        .toString()
                                        .isNotEmpty) ...[
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF00008b)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          data['animeName'],
                                          style: TextStyle(
                                            color: Color(0xFF00008b),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // 矢印アイコン（改良版）
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF00008b).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFF00008b),
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

// フォールバックアバターの構築
  Widget _buildFallbackAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF00008b),
            Color(0xFF0000CD),
          ],
        ),
      ),
      child: Icon(
        Icons.location_on_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  void _addCurrentLocationCircle() {
    if (_currentPosition != null) {
      setState(() {
        _circles.add(
          Circle(
            circleId: const CircleId('current_location'),
            center: _currentPosition!,
            radius: 10,
            fillColor: Colors.blue.withOpacity(0.3),
            strokeColor: Colors.blue,
            strokeWidth: 2,
          ),
        );
      });
    }
  }

  void _moveToCurrentLocation() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition!,
            zoom: 16.0,
            bearing: 30.0,
            tilt: 60.0,
          ),
        ),
      );
    }
  }

  void _showLocationPermissionDialog({
    String message = '位置情報の許可が必要です。',
    String actionText = '設定を開く',
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('位置情報の許可が必要です'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              const url = 'app-settings:';
              if (await canLaunch(url)) {
                await launch(url);
              } else {
                print('Could not launch $url');
              }
              Navigator.of(context).pop();
            },
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _calculateDistance(LatLng markerPosition) async {
    if (_currentPosition != null) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        markerPosition.latitude,
        markerPosition.longitude,
      );

      bool wasInRange = _canCheckIn;
      setState(() {
        _canCheckIn = distance <= 500;
      });

      if (!wasInRange && _canCheckIn) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('locations')
            .doc(_selectedMarker!.markerId.value)
            .get();

        if (doc.exists) {
          String locationName =
              (doc.data() as Map<String, dynamic>)['title'] ?? '';
          bool hasCheckedIn =
              await _hasCheckedIn(_selectedMarker!.markerId.value);

          await NotificationService.showCheckInAvailableNotification(
            locationName,
            _userId,
            _selectedMarker!.markerId.value,
            hasCheckedIn,
          );
        }
      }
    }
  }

  Future<void> _loadMarkersFromFirestore() async {
    try {
      CollectionReference locations =
          FirebaseFirestore.instance.collection('locations');

      // Initial query to get a batch of locations
      QuerySnapshot snapshot = await locations.limit(_markerBatchSize).get();
      _pendingMarkers = snapshot.docs;

      // Process the first batch immediately
      await _processMarkerBatch();

      // Set up a map camera movement listener to load more markers when needed
      if (_mapController != null) {
        // We can set up a listener on camera idle to load more markers in view
        // This functionality would need to be implemented in onMapCreated
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading markers: $e');
      setState(() {
        _isLoading = false;
        _errorOccurred = true;
      });
    }
  }

// Load markers from the current camera position
  Future<void> _loadNearbyMarkers() async {
    if (_isLoadingNearbyMarkers || _mapController == null) return;

    setState(() {
      _isLoadingNearbyMarkers = true;
    });

    try {
      // 現在のカメラ位置を取得
      LatLngBounds visibleRegion = await _mapController!.getVisibleRegion();
      LatLng center = LatLng(
          (visibleRegion.northeast.latitude +
                  visibleRegion.southwest.latitude) /
              2,
          (visibleRegion.northeast.longitude +
                  visibleRegion.southwest.longitude) /
              2);

      // 表示範囲の半径をメートル単位で計算
      double distanceInMeters = Geolocator.distanceBetween(
              visibleRegion.northeast.latitude,
              visibleRegion.northeast.longitude,
              visibleRegion.southwest.latitude,
              visibleRegion.southwest.longitude) /
          2;

      // 範囲内の位置情報を取得
      CollectionReference locations =
          FirebaseFirestore.instance.collection('locations');
      QuerySnapshot snapshot = await locations.get();

      // _pendingMarkersと同じ型の空のリストを作成
      List<QueryDocumentSnapshot<Object?>> nearbyDocs = [];

      // ドキュメントを手動でフィルタリング
      for (var doc in snapshot.docs) {
        // nullチェック付きで安全にデータを取得
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // 有効な緯度/経度がないドキュメントをスキップ
        if (data['latitude'] == null || data['longitude'] == null) {
          continue;
        }

        // nullチェック付きで安全にdoubleに変換
        double? lat = data['latitude'] is num
            ? (data['latitude'] as num).toDouble()
            : null;
        double? lng = data['longitude'] is num
            ? (data['longitude'] as num).toDouble()
            : null;

        // 有効な座標が取得できなかった場合はスキップ
        if (lat == null || lng == null) {
          continue;
        }

        double distance = Geolocator.distanceBetween(
            center.latitude, center.longitude, lat, lng);

        // このマーカーが既にマップ上にあるかチェック
        bool alreadyExists =
            _markers.any((marker) => marker.markerId.value == doc.id);

        if (!alreadyExists && distance <= distanceInMeters * 1.5) {
          // 同じ型のリストに追加
          nearbyDocs.add(doc);
        }
      }

      // addAllを使わずに_pendingMarkersを直接更新
      setState(() {
        _pendingMarkers = [..._pendingMarkers, ...nearbyDocs];
      });

      // バッチを処理
      await _processMarkerBatch();

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('${nearbyDocs.length}個の新しいマーカーを読み込みました'),
      //     duration: Duration(seconds: 2),
      //   ),
      // );
    } catch (e) {
      print('Error loading nearby markers: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('マーカーの読み込みに失敗しました'),
      //     duration: Duration(seconds: 2),
      //   ),
      // );
    } finally {
      setState(() {
        _isLoadingNearbyMarkers = false;
      });
    }
  }

  Future<void> _processMarkerBatch() async {
    if (_pendingMarkers.isEmpty || _isLoadingMoreMarkers) return;

    setState(() {
      _isLoadingMoreMarkers = true;
    });

    // Process a limited number of markers at once to avoid UI freezing
    final batch = _pendingMarkers.take(_markerBatchSize).toList();
    _pendingMarkers = _pendingMarkers.skip(_markerBatchSize).toList();

    // Use compute for processing markers on a separate isolate for better performance
    List<Future<Marker?>> markerFutures = [];

    for (var doc in batch) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      double latitude = (data['latitude'] as num).toDouble();
      double longitude = (data['longitude'] as num).toDouble();
      LatLng position = LatLng(latitude, longitude);

      // No distance check - load all markers regardless of distance
      String imageUrl = data['imageUrl'];
      String locationId = doc.id;
      String title = data['title'];
      String animeName = data['animeName'] ?? '';
      String description = data['description'] ?? '';

      markerFutures.add(_createMarkerWithImage(
        position,
        imageUrl,
        locationId,
        300,
        200,
        title,
        animeName,
        description,
      ));
    }

    // Wait for all markers to be created
    List<Marker?> newMarkers = await Future.wait(markerFutures);

    // Add the valid markers to the map
    setState(() {
      for (var marker in newMarkers) {
        if (marker != null) {
          _markers.add(marker);
        }
      }
      _isLoadingMoreMarkers = false;
    });

    // If there are more markers to process, schedule the next batch
    if (_pendingMarkers.isNotEmpty) {
      Future.delayed(Duration(milliseconds: 300), () {
        _processMarkerBatch();
      });
    }
  }

  Future<Marker?> _createMarkerWithImage(
    LatLng position,
    String imageUrl,
    String markerId,
    int width,
    int height,
    String title,
    String animeName,
    String snippet,
  ) async {
    try {
      final Uint8List markerIcon =
          await _getBytesFromUrl(imageUrl, width, height);

      // Use compute to move image processing to a separate isolate
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint = Paint()..color = Colors.white;

      // 吹き出しの描画（先端を下に移動）
      final Path path = Path();
      path.moveTo(0, 0);
      path.lineTo(0, height + 20);
      path.lineTo((width + 40) / 2 - 10, height + 20);
      path.lineTo((width + 40) / 2, height + 40);
      path.lineTo((width + 40) / 2 + 10, height + 20);
      path.lineTo(width + 40, height + 20);
      path.lineTo(width + 40, 0);
      path.close();

      canvas.drawPath(path, paint);

      // 画像の描画
      final ui.Image image = await decodeImageFromList(markerIcon);

      const double scaleFactor = 0.95;
      final double scaledWidth = (width + 40) * scaleFactor;
      final double scaledHeight = (height + 20) * scaleFactor;
      final double offsetX = ((width + 40) - scaledWidth) / 2;
      final double offsetY = ((height + 20) - scaledHeight) / 2;

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight),
        Paint(),
      );

      final img =
          await pictureRecorder.endRecording().toImage(width + 40, height + 60);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);

      if (data == null) return null;

      return Marker(
        markerId: MarkerId(markerId),
        position: position,
        icon: BitmapDescriptor.fromBytes(data.buffer.asUint8List()),
        onTap: () async {
          // Update selected marker
          setState(() {
            _selectedMarker = Marker(
              markerId: MarkerId(markerId),
              position: position,
              icon: BitmapDescriptor.fromBytes(data.buffer.asUint8List()),
            );
          });

          // Calculate distance for check-in possibility
          _calculateDistance(position);

          // Check if user has already checked in
          bool hasCheckedIn = await _hasCheckedIn(markerId);

          // Show bottom sheet if the widget is still mounted
          if (!mounted) return;

          // Show modal bottom sheet
          _showModalBottomSheet(
            context,
            imageUrl,
            title,
            animeName,
            snippet,
            hasCheckedIn,
          );
        },
      );
    } catch (e) {
      print('Error creating marker: $e');
      return null;
    }
  }

  // Optimized method to fetch image bytes from URL
  Future<Uint8List> _getBytesFromUrl(String url, int width, int height) async {
    try {
      final http.Response response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load image, status code: ${response.statusCode}');
      }

      final ui.Codec codec = await ui.instantiateImageCodec(
        response.bodyBytes,
        targetWidth: width,
        targetHeight: height,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ByteData? byteData =
          await fi.image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      print('Error loading image from URL: $e');
      // Return a fallback/placeholder image or rethrow
      throw e;
    }
  }

  Future<bool> _hasCheckedIn(String locationId) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('check_ins')
        .where('locationId', isEqualTo: locationId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  void _showModalBottomSheet(BuildContext context, String imageUrl,
      String title, String animeName, String snippet, bool hasCheckedIn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10.0),
                    SizedBox(
                      height: 150,
                      width: 250,
                      child: Image.network(imageUrl),
                    ),
                    const SizedBox(height: 10.0),
                    Column(
                      children: [
                        Text(
                          animeName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                    if (_selectedMarker != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // チェックインボタン
                          if (hasCheckedIn)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.grey),
                                  const Text(
                                    'チェックイン済み',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _canCheckIn
                                      ? const Color(0xFF00008b)
                                      : Colors.grey,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                                onPressed: _canCheckIn
                                    ? () {
                                        _checkIn(title,
                                            _selectedMarker!.markerId.value);
                                        Navigator.pop(context);
                                      }
                                    : null,
                                child: Column(
                                  children: [
                                    Icon(Icons.place,
                                        color: Colors.white, size: 20),
                                    const Text(
                                      'チェックイン',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // スポットを見るボタン
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00008b),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              onPressed: () async {
                                DocumentSnapshot snapshot =
                                    await FirebaseFirestore.instance
                                        .collection('locations')
                                        .doc(_selectedMarker!.markerId.value)
                                        .get();

                                if (snapshot.exists) {
                                  Map<String, dynamic> data =
                                      snapshot.data() as Map<String, dynamic>;

                                  // subMediaの処理
                                  List<Map<String, dynamic>> subMediaList = [];
                                  if (data['subMedia'] != null &&
                                      data['subMedia'] is List) {
                                    subMediaList =
                                        (data['subMedia'] as List).map((item) {
                                      return {
                                        'type': item['type'] as String? ?? '',
                                        'url': item['url'] as String? ?? '',
                                        'title': item['title'] as String? ?? '',
                                      };
                                    }).toList();
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SpotDetailScreen(
                                        title: data['title'] ?? '',
                                        description: data['description'] ?? '',
                                        spot_description:
                                            data['spot_description'] ?? '',
                                        latitude: data['latitude'] != null
                                            ? (data['latitude'] as num)
                                                .toDouble()
                                            : 0.0,
                                        longitude: data['longitude'] != null
                                            ? (data['longitude'] as num)
                                                .toDouble()
                                            : 0.0,
                                        imageUrl: data['imageUrl'] ?? '',
                                        sourceTitle: data['sourceTitle'] ?? '',
                                        subsourceTitle:
                                            data['subsourceTitle'] ?? '',
                                        sourceLink: data['sourceLink'] ?? '',
                                        subsourceLink:
                                            data['subsourceLink'] ?? '',
                                        url: data['url'] ?? '',
                                        subMedia: subMediaList,
                                        locationId:
                                            _selectedMarker!.markerId.value,
                                        animeName: data['animeName'] ?? '',
                                        userId: data['userId'] ?? '',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Column(
                                children: [
                                  Icon(Icons.visibility,
                                      color: Colors.white, size: 20),
                                  const Text(
                                    'スポットを見る',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ルート案内ボタン
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00008b),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                if (_selectedMarker != null) {
                                  _showNavigationModalBottomSheet(
                                      context, _selectedMarker!.position);
                                }
                              },
                              child: Column(
                                children: [
                                  Icon(Icons.directions,
                                      color: Colors.white, size: 20),
                                  const Text(
                                    'ルート案内・その他',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (!_canCheckIn && !hasCheckedIn)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          '現在位置から離れているためチェックインできません',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  StreamSubscription<DocumentSnapshot>? _favoriteSubscription;

  // Google Routes API を呼び出してルートを取得するメソッド
// Google Routes API を呼び出してルートを取得するメソッド（修正版）
  Future<void> _getRouteWithAPI(LatLng origin, LatLng destination) async {
    if (_isLoadingRoute) return;

    setState(() {
      _isLoadingRoute = true;
      _routeDuration = null;
      _routeDistance = null;
    });

    try {
      // APIキーを設定 - 実際のAPIキーに置き換えてください
      const String apiKey = 'AIzaSyCotKIa2a4mjj3FOeF5gy04iGUhsxHHJrY';

      // APIキーが設定されていない場合はフォールバック処理
      if (apiKey == 'AIzaSyCotKIa2a4mjj3FOeF5gy04iGUhsxHHJrY' ||
          apiKey.isEmpty) {
        print('Google Routes API key not configured, using fallback method');
        await _showSimpleRoute(origin, destination);
        return;
      }

      // Routes API エンドポイント
      final String url =
          'https://routes.googleapis.com/directions/v2:computeRoutes';

      // Google Routes APIで期待される正しいトラベルモード値にマッピング
      String apiTravelMode;
      switch (_selectedTravelMode) {
        case 'WALK':
          apiTravelMode = 'WALK';
          break;
        case 'BICYCLE':
          apiTravelMode = 'BICYCLE';
          break;
        case 'TRANSIT':
          apiTravelMode = 'TRANSIT';
          break;
        case 'DRIVE':
        default:
          apiTravelMode = 'DRIVE';
          break;
      }

      print(
          'Selected travel mode: $_selectedTravelMode -> API mode: $apiTravelMode');

      // Routes API リクエストボディを構築（修正版）
      Map<String, dynamic> requestBody = {
        'origin': {
          'location': {
            'latLng': {
              'latitude': origin.latitude,
              'longitude': origin.longitude
            }
          }
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': destination.latitude,
              'longitude': destination.longitude
            }
          }
        },
        'travelMode': apiTravelMode,
        'computeAlternativeRoutes': false,
        'languageCode': 'ja-JP',
        'units': 'METRIC'
      };

      // 移動手段に応じて追加設定
      if (apiTravelMode == 'DRIVE') {
        requestBody['routingPreference'] = 'TRAFFIC_AWARE';
        requestBody['routeModifiers'] = {
          'avoidTolls': false,
          'avoidHighways': false,
          'avoidFerries': false
        };
      } else if (apiTravelMode == 'TRANSIT') {
        // 公共交通機関の場合の設定
        requestBody['transitPreferences'] = {
          'allowedTravelModes': ['BUS', 'SUBWAY', 'TRAIN', 'LIGHT_RAIL'],
          'routingPreference': 'FEWER_TRANSFERS'
        };
      } else if (apiTravelMode == 'WALK') {
        // 徒歩の場合の設定
        requestBody['routingPreference'] = 'TRAFFIC_UNAWARE';
      } else if (apiTravelMode == 'BICYCLE') {
        // 自転車の場合の設定
        requestBody['routingPreference'] = 'TRAFFIC_UNAWARE';
      }

      // デバッグ用：リクエストボディをログ出力
      print('API Request body: ${json.encode(requestBody)}');

      // リクエストヘッダーを設定
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs,routes.travelAdvisory'
      };

      // API リクエストを送信
      final response = await http
          .post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(requestBody),
      )
          .timeout(
        Duration(seconds: 20), // タイムアウトを延長
        onTimeout: () {
          throw TimeoutException('ルート計算がタイムアウトしました。');
        },
      );

      print('API Response status: ${response.statusCode}');
      print('API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('routes') &&
            data['routes'] is List &&
            data['routes'].isNotEmpty) {
          print('Routes found: ${data['routes'].length}');
          _drawRouteFromRoutesAPI(data);
          _displayRouteSummary(data);
        } else {
          print(
              'No routes found in the response for travel mode: $apiTravelMode');
          // APIでルートが見つからない場合、フォールバック処理を実行
          await _showSimpleRoute(origin, destination);
        }
      } else {
        print('Routes API error: ${response.statusCode}, ${response.body}');
        // APIエラーの場合はフォールバック処理を実行
        await _showSimpleRoute(origin, destination);
      }
    } catch (e) {
      print('Error fetching route for mode $_selectedTravelMode: $e');
      // エラーの場合もフォールバック処理を実行
      await _showSimpleRoute(origin, destination);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  // シンプルなルート表示のフォールバックメソッド
// シンプルなルート表示のフォールバックメソッド（修正版）
// シンプルなルート表示のフォールバックメソッド（修正版）
  Future<void> _showSimpleRoute(LatLng origin, LatLng destination) async {
    try {
      print('Using fallback route calculation for mode: $_selectedTravelMode');

      // 直線ルートを作成
      List<LatLng> routePoints = [origin, destination];

      // 距離を計算
      double distanceInMeters = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );

      // 概算の所要時間を計算（移動手段に基づく）
      double speedKmH;
      String modeName;
      switch (_selectedTravelMode) {
        case 'WALK':
          speedKmH = 4.8; // 徒歩 4.8km/h（一般的な歩行速度）
          modeName = '徒歩';
          break;
        case 'BICYCLE':
          speedKmH = 15.0; // 自転車 15km/h
          modeName = '自転車';
          break;
        case 'TRANSIT':
          speedKmH = 20.0; // 公共交通機関 20km/h（待ち時間含む）
          modeName = '公共交通';
          break;
        case 'DRIVE':
        default:
          speedKmH = 30.0; // 車 30km/h（都市部平均、信号待ち含む）
          modeName = '車';
          break;
      }

      double distanceKm = distanceInMeters / 1000;
      double timeHours = distanceKm / speedKmH;
      int timeMinutes = (timeHours * 60).round();

      // 最小時間を設定（徒歩の場合）
      if (_selectedTravelMode == 'WALK' && timeMinutes < 1) {
        timeMinutes = 1;
      }

      // ポリラインを作成
      final PolylineId polylineId = PolylineId('simple_route');
      final Polyline polyline = Polyline(
        polylineId: polylineId,
        consumeTapEvents: true,
        color: _getTravelModeColor(_selectedTravelMode),
        width: _selectedTravelMode == 'WALK' ? 3 : 4,
        points: routePoints,
        patterns: _selectedTravelMode == 'TRANSIT'
            ? [PatternItem.dash(15), PatternItem.gap(8)]
            : _selectedTravelMode == 'WALK'
                ? [PatternItem.dash(15), PatternItem.gap(5)]
                : [],
      );

      // ルートを表示
      setState(() {
        _polylines.clear();
        _routePolylines.clear();
        _routePolylines[polylineId] = polyline;
        _polylines.add(polyline);

        // 概算の時間と距離を設定
        if (timeHours >= 1) {
          _routeDuration = '約${timeHours.floor()}時間${(timeMinutes % 60)}分';
        } else {
          _routeDuration = '約${timeMinutes}分';
        }

        _routeDistance = distanceInMeters >= 1000
            ? '${(distanceInMeters / 1000).toStringAsFixed(1)} km'
            : '${distanceInMeters.toInt()} m';
      });

      // カメラを調整
      double minLat = math.min(origin.latitude, destination.latitude);
      double maxLat = math.max(origin.latitude, destination.latitude);
      double minLng = math.min(origin.longitude, destination.longitude);
      double maxLng = math.max(origin.longitude, destination.longitude);

      // パディングを追加
      double latPadding = (maxLat - minLat) * 0.3;
      double lngPadding = (maxLng - minLng) * 0.3;

      // 最小パディングを設定
      if (latPadding < 0.001) latPadding = 0.001;
      if (lngPadding < 0.001) lngPadding = 0.001;

      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );

      // フォールバック使用を通知
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$modeName（概算）: $_routeDuration, $_routeDistance'),
            duration: Duration(seconds: 4),
            backgroundColor:
                _getTravelModeColor(_selectedTravelMode).withOpacity(0.9),
          ),
        );
      }
    } catch (e) {
      print('Error in fallback route: $e');
      _showErrorSnackbar('ルートの表示に失敗しました');
    }
  }

  // エラーメッセージを表示するヘルパーメソッド
  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Routes API のレスポンスからルートを描画するメソッド
  void _drawRouteFromRoutesAPI(Map<String, dynamic> routesData) {
    // 以前のルートをクリア
    setState(() {
      _polylines.clear();
      _routePolylines.clear();
    });

    // レスポンスからエンコードされたポリラインを取得
    final String encodedPolyline =
        routesData['routes'][0]['polyline']['encodedPolyline'];

    // ポリラインをデコード
    List<LatLng> polylineCoordinates = _decodePolyline(encodedPolyline);

    // ルートのポリラインを作成
    final PolylineId polylineId = PolylineId('route');
    final Polyline polyline = Polyline(
      polylineId: polylineId,
      consumeTapEvents: true,
      color: _getTravelModeColor(_selectedTravelMode),
      width: 5,
      points: polylineCoordinates,
      // オプション: 移動手段によって線のスタイルを変える
      patterns: _selectedTravelMode == 'TRANSIT'
          ? [PatternItem.dash(20), PatternItem.gap(10)]
          : [],
    );

    // ポリラインをセット
    setState(() {
      _routePolylines[polylineId] = polyline;
      _polylines.add(polyline);
    });

    // カメラの境界を計算して表示範囲を調整
    if (polylineCoordinates.isNotEmpty) {
      double minLat = polylineCoordinates[0].latitude;
      double maxLat = polylineCoordinates[0].latitude;
      double minLng = polylineCoordinates[0].longitude;
      double maxLng = polylineCoordinates[0].longitude;

      for (final LatLng point in polylineCoordinates) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      // カメラを移動
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
  }

  // ルートの概要情報（所要時間・距離）を表示するメソッド
  void _displayRouteSummary(Map<String, dynamic> routesData) {
    try {
      final route = routesData['routes'][0];
      print('Processing route summary: ${route.keys}');

      // 所要時間を処理（より柔軟な処理）
      String durationText = '不明';
      if (route.containsKey('duration')) {
        final durationStr = route['duration'].toString();
        if (durationStr.endsWith('s')) {
          final int durationSeconds =
              int.parse(durationStr.replaceAll('s', ''));
          final Duration duration = Duration(seconds: durationSeconds);

          if (duration.inHours > 0) {
            durationText = '${duration.inHours}時間${(duration.inMinutes % 60)}分';
          } else {
            durationText = '${duration.inMinutes}分';
          }
        }
      } else if (route.containsKey('legs') &&
          route['legs'] is List &&
          route['legs'].isNotEmpty) {
        // legsから所要時間を取得する方法
        int totalSeconds = 0;
        for (var leg in route['legs']) {
          if (leg.containsKey('duration')) {
            final legDurationStr = leg['duration'].toString();
            if (legDurationStr.endsWith('s')) {
              totalSeconds += int.parse(legDurationStr.replaceAll('s', ''));
            }
          }
        }
        if (totalSeconds > 0) {
          final Duration duration = Duration(seconds: totalSeconds);
          if (duration.inHours > 0) {
            durationText = '${duration.inHours}時間${(duration.inMinutes % 60)}分';
          } else {
            durationText = '${duration.inMinutes}分';
          }
        }
      }

      // 距離を処理（より柔軟な処理）
      String distanceText = '不明';
      if (route.containsKey('distanceMeters')) {
        final int distanceMeters = route['distanceMeters'];
        distanceText = distanceMeters >= 1000
            ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
            : '$distanceMeters m';
      } else if (route.containsKey('legs') &&
          route['legs'] is List &&
          route['legs'].isNotEmpty) {
        // legsから距離を取得する方法
        int totalMeters = 0;
        for (var leg in route['legs']) {
          if (leg.containsKey('distanceMeters')) {
            totalMeters += leg['distanceMeters'] as int;
          }
        }
        if (totalMeters > 0) {
          distanceText = totalMeters >= 1000
              ? '${(totalMeters / 1000).toStringAsFixed(1)} km'
              : '$totalMeters m';
        }
      }

      print('Calculated duration: $durationText, distance: $distanceText');

      // 状態を更新して UI に反映
      setState(() {
        _routeDuration = durationText;
        _routeDistance = distanceText;
      });

      // 移動手段名を取得
      String travelModeName;
      switch (_selectedTravelMode) {
        case 'WALK':
          travelModeName = '徒歩';
          break;
        case 'BICYCLE':
          travelModeName = '自転車';
          break;
        case 'TRANSIT':
          travelModeName = '公共交通';
          break;
        case 'DRIVE':
        default:
          travelModeName = '車';
          break;
      }

      // スナックバーで表示（移動手段を含む）
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('$travelModeName: 所要時間 $durationText, 距離 $distanceText'),
            duration: Duration(seconds: 4),
            backgroundColor: _getTravelModeColor(_selectedTravelMode),
          ),
        );
      }
    } catch (e) {
      print('Error processing route summary: $e');
      setState(() {
        _routeDuration = 'エラー';
        _routeDistance = 'エラー';
      });
    }
  }

  // エンコードされたポリラインをデコードするヘルパーメソッド
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final double latDouble = lat / 1E5;
      final double lngDouble = lng / 1E5;

      poly.add(LatLng(latDouble, lngDouble));
    }

    return poly;
  }

  // 移動手段に基づいて色を変更するヘルパーメソッド
  Color _getTravelModeColor(String travelMode) {
    switch (travelMode) {
      case 'DRIVE':
        return Colors.blue;
      case 'WALK':
        return Colors.green;
      case 'BICYCLE':
        return Colors.purple;
      case 'TRANSIT':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  // 移動手段を切り替えるメソッド
  void _changeTravelMode(String mode) {
    setState(() {
      _selectedTravelMode = mode;
    });

    // 現在の目的地に対して再度ルートを計算
    if (_currentPosition != null && _selectedMarker != null) {
      _getRouteWithAPI(_currentPosition!, _selectedMarker!.position);
    }
  }

  // 移動手段選択UIをボトムシートに追加
  Widget _buildTravelModeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _travelModeButton('DRIVE', Icons.directions_car, '車'),
        _travelModeButton('WALK', Icons.directions_walk, '徒歩'),
        _travelModeButton('BICYCLE', Icons.directions_bike, '自転車'),
        _travelModeButton('TRANSIT', Icons.directions_transit, '公共交通'),
      ],
    );
  }

  Widget _travelModeButton(String mode, IconData icon, String label) {
    final bool isSelected = _selectedTravelMode == mode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              icon,
              color: isSelected ? const Color(0xFF00008b) : Colors.grey,
            ),
            onPressed: () {
              // 同じモードが選択された場合は何もしない
              if (mode == _selectedTravelMode) return;

              setState(() {
                _selectedTravelMode = mode;
                // 選択時にローディング状態をリセット
                _isLoadingRoute = false;
              });

              // 現在の目的地に対して再度ルートを計算
              if (_currentPosition != null && _selectedMarker != null) {
                _getRouteWithAPI(_currentPosition!, _selectedMarker!.position);
              }
            },
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF00008b) : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ルート情報表示ウィジェット
  Widget _buildRouteInfoCard() {
    if (_routeDuration == null || _routeDistance == null) {
      return SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInfoItem(
                    icon: Icons.access_time_rounded,
                    value: _routeDuration!,
                    label: '所要時間',
                    color: Colors.blue,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  _buildInfoItem(
                    icon: Icons.straighten_rounded,
                    value: _routeDistance!,
                    label: '距離',
                    color: Colors.green,
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_currentPosition != null &&
                            _selectedMarker != null) {
                          _getRouteWithAPI(
                              _currentPosition!, _selectedMarker!.position);
                        }
                      },
                      icon: Icon(Icons.refresh_rounded, size: 18),
                      label: Text('再計算'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFF00008b),
                        side: BorderSide(color: Color(0xFF00008b)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_selectedMarker != null) {
                          _launchExternalNavigation(
                            _selectedMarker!.position.latitude,
                            _selectedMarker!.position.longitude,
                          );
                        }
                      },
                      icon: Icon(Icons.navigation_rounded, size: 18),
                      label: Text('ナビ開始'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00008b),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.grey.shade800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showNavigationModalBottomSheet(
      BuildContext context, LatLng destination) async {
    // ローディング状態をリセット
    setState(() {
      _isLoadingRoute = false;
      _routeDuration = null;
      _routeDistance = null;
    });

    // Firebase Firestoreのリスナーを設定
    _favoriteSubscription = FirebaseFirestore.instance
        .collection('favorites')
        .doc(_selectedMarker!.markerId.value)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _isFavorite = snapshot['isFavorite'];
        });
      }
    });

    // ルートを計算
    _showRouteOnMap(destination);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter bottomSheetSetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.2,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, controller) {
                return SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),

                      // 上部のアクションボタン（ナビ、詳細、投稿、リンク、お気に入り）
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.navigation),
                                onPressed: () {
                                  _launchExternalNavigation(
                                      destination.latitude,
                                      destination.longitude);
                                },
                              ),
                              const Text('ナビ'),
                            ],
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.more_horiz),
                                onPressed: () async {
                                  DocumentSnapshot snapshot =
                                      await FirebaseFirestore.instance
                                          .collection('locations')
                                          .doc(_selectedMarker!.markerId.value)
                                          .get();

                                  if (snapshot.exists) {
                                    Map<String, dynamic>? data = snapshot.data()
                                        as Map<String, dynamic>?;
                                    if (data != null) {
                                      // subMediaの処理を追加
                                      List<Map<String, dynamic>> subMediaList =
                                          [];
                                      if (data['subMedia'] != null &&
                                          data['subMedia'] is List) {
                                        subMediaList =
                                            (data['subMedia'] as List)
                                                .map((item) {
                                          return {
                                            'type':
                                                item['type'] as String? ?? '',
                                            'url': item['url'] as String? ?? '',
                                            'title':
                                                item['title'] as String? ?? '',
                                          };
                                        }).toList();
                                      }

                                      // すべての必要なデータをSpotDetailScreenに渡す
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              SpotDetailScreen(
                                            locationId:
                                                _selectedMarker!.markerId.value,
                                            title: data['title'] ?? '',
                                            description:
                                                data['description'] ?? '',
                                            spot_description:
                                                data['spot_description'] ?? '',
                                            latitude: data['latitude'] != null
                                                ? (data['latitude'] as num)
                                                    .toDouble()
                                                : 0.0,
                                            longitude: data['longitude'] != null
                                                ? (data['longitude'] as num)
                                                    .toDouble()
                                                : 0.0,
                                            imageUrl: data['imageUrl'] ?? '',
                                            sourceTitle:
                                                data['sourceTitle'] ?? '',
                                            subsourceTitle:
                                                data['subsourceTitle'] ?? '',
                                            sourceLink:
                                                data['sourceLink'] ?? '',
                                            subsourceLink:
                                                data['subsourceLink'] ?? '',
                                            url: data['url'] ?? '',
                                            subMedia: subMediaList,
                                            animeName: data['animeName'] ?? '',
                                            userId: data['userId'] ?? '',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              const Text('詳細'),
                            ],
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.post_add),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PostScreen(
                                        locationId:
                                            _selectedMarker!.markerId.value,
                                        userId: _userId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const Text('投稿'),
                            ],
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.link),
                                onPressed: () async {
                                  DocumentSnapshot snapshot =
                                      await FirebaseFirestore.instance
                                          .collection('locations')
                                          .doc(_selectedMarker!.markerId.value)
                                          .get();
                                  if (snapshot.exists) {
                                    Map<String, dynamic>? data = snapshot.data()
                                        as Map<String, dynamic>?;
                                    if (data != null &&
                                        data.containsKey('sourceLink')) {
                                      final String sourceLink =
                                          data['sourceLink'];
                                      //Open URL
                                      if (await canLaunch(sourceLink)) {
                                        await launch(sourceLink);
                                      } else {
                                        //No Open URL
                                        print('Could not launch $sourceLink');
                                      }
                                    }
                                  }
                                },
                              ),
                              const Text('リンク'),
                            ],
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isFavorite = !_isFavorite;
                                  });
                                  _toggleFavorite(
                                      _selectedMarker!.markerId.value);
                                },
                              ),
                              const Text('お気に入り'),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 交通手段選択（下部に移動）
                      _buildTravelModeSelector(),

                      const SizedBox(height: 10),

                      // ルート情報表示
                      if (_isLoadingRoute)
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('ルート計算中...'),
                            ],
                          ),
                        )
                      else if (_routeDuration != null && _routeDistance != null)
                        _buildRouteInfoCard()
                      else
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'ルート情報を取得できませんでした。\n別の移動手段を選択するか、再試行してください。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // 投稿された画像のグリッド
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future:
                            _getPostedImages(_selectedMarker!.markerId.value),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          } else if (snapshot.hasError) {
                            return const Text('エラーが発生しました');
                          } else if (snapshot.hasData &&
                              snapshot.data!.isNotEmpty) {
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                              itemCount: snapshot.data!.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PostDetailScreen(
                                            postData: snapshot.data![index]),
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    snapshot.data![index]['imageUrl'],
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            );
                          } else {
                            return const Text('まだ投稿されていません。');
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      // モーダルが閉じたときにリスナーとルートをクリーンアップ
      _favoriteSubscription?.cancel();
      setState(() {
        _polylines.clear();
        _routePolylines.clear();
        _isLoadingRoute = false;
      });
    });
  }

  Future<void> _toggleFavorite(String locationId) async {
    try {
      DocumentReference userFavoriteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .doc(locationId);

      DocumentSnapshot favoriteSnapshot = await userFavoriteRef.get();

      if (favoriteSnapshot.exists) {
        // お気に入りから削除
        await userFavoriteRef.delete();
        setState(() {
          _isFavorite = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お気に入りから削除しました')),
        );
      } else {
        // お気に入りに追加
        await userFavoriteRef.set({
          'locationId': locationId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        setState(() {
          _isFavorite = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お気に入りに追加しました')),
        );
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お気に入りの更新に失敗しました')),
      );
    }
  }

  Future<bool> _checkFavoriteStatus(String locationId) async {
    DocumentSnapshot favoriteSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('favorites')
        .doc(locationId)
        .get();

    return favoriteSnapshot.exists;
  }

  Future<void> _uploadImage(String locationId) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      File file = File(image.path);
      try {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('location_images')
            .child(locationId)
            .child(fileName);

        await ref.putFile(file);
        String downloadURL = await ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('locations')
            .doc(locationId)
            .collection('images')
            .add({
          'url': downloadURL,
          'userId': _userId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像をアップロードしました')),
        );
      } catch (e) {
        print('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像のアップロードに失敗しました')),
        );
      }
    }
  }

  // 既存の_showRouteOnMapメソッドを置き換え
  void _showRouteOnMap(LatLng destination) {
    if (_currentPosition != null) {
      try {
        // 古いルートをクリアする
        setState(() {
          _polylines.clear();
          _routePolylines.clear();
          _routeDuration = null;
          _routeDistance = null;
        });

        // Routes API を使用してルートを取得
        _getRouteWithAPI(_currentPosition!, destination);
      } catch (e) {
        print('Error showing route: $e');
        _showErrorSnackbar('ルート表示中にエラーが発生しました');
        setState(() {
          _isLoadingRoute = false;
        });
      }
    } else {
      _showErrorSnackbar('現在位置が取得できていません');
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getPostedImages(String locationId) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('locations')
        .doc(locationId)
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  // _checkIn メソッドを修正して Firebase Functions の sendCheckInEmail を呼び出す
// この関数は MapSubscriptionEn クラスの _checkIn メソッド内に追加します

  void _checkIn(String title, String locationId) async {
    setState(() {
      _isSubmitting = true;
      _showConfirmation = true;
    });

    try {
      //ユーザー情報を取得
      User currentUser = FirebaseAuth.instance.currentUser!;
      String userEmail = currentUser.email ?? '';

      // デバッグログを追加
      print('チェックイン開始: locationId=$locationId, title=$title');

      // 既存のチェックイン記録を追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('check_ins')
          .add({
        'title': title,
        'locationId': locationId,
        'timestamp': FieldValue.serverTimestamp(),
        'userEmail': FirebaseAuth.instance.currentUser?.email,
      });

      print('Firestoreにチェックインデータを保存しました');

      // ユーザードキュメントの参照を取得
      DocumentReference userRef =
          FirebaseFirestore.instance.collection('users').doc(_userId);

      // ロケーションの参照を取得
      DocumentReference locationRef =
          FirebaseFirestore.instance.collection('locations').doc(locationId);

      // トランザクションで複数の更新を実行
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // ロケーションドキュメントを取得
        DocumentSnapshot locationSnapshot = await transaction.get(locationRef);
        // ユーザードキュメントを取得
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        if (locationSnapshot.exists) {
          // チェックインカウントを更新
          int currentCount = (locationSnapshot.data()
                  as Map<String, dynamic>)['checkinCount'] ??
              0;
          transaction.update(locationRef, {'checkinCount': currentCount + 1});
        }

        if (userSnapshot.exists) {
          // 現在のポイントとcorrectCountを取得
          Map<String, dynamic> userData =
              userSnapshot.data() as Map<String, dynamic>;
          int currentPoints = userData['points'] ?? 0;
          int currentCorrectCount = userData['correctCount'] ?? 0;

          // ポイントとcorrectCountを更新
          transaction.update(userRef, {
            'points': currentPoints + 1,
            'correctCount': currentCorrectCount + 1,
          });
        } else {
          // ユーザードキュメントが存在しない場合は新規作成
          transaction.set(userRef, {
            'points': 1,
            'correctCount': 1,
          });
        }
      });

      print('Firestoreトランザクションが完了しました');

      // ポイント履歴を記録
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('point_history')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'points': 1,
        'type': 'checkin',
        'locationId': locationId,
        'locationTitle': title,
      });

      print('ポイント履歴を記録しました');

      // Firebase Functionsを呼び出してメールを送信
      try {
        print('sendCheckInEmail関数を呼び出し開始');

        // Firebase Functionsのインスタンスを取得
        final HttpsCallable callable =
            FirebaseFunctions.instanceFor(region: 'asia-northeast1')
                .httpsCallable('sendCheckInEmail');

        // デバッグ: データのログ出力5
        print('送信データ: locationId=$locationId, title=$title');

        // Firebase Functionsを呼び出す
        final result =
            await callable.call({'locationId': locationId, 'title': title});

        // レスポンスのデバッグログ
        print('Function実行結果: ${result.data}');

        if (result.data['success'] == true) {
          print('メール送信成功: ${result.data['message']}');
        } else {
          print('メール送信失敗: ${result.data['message'] ?? "不明なエラー"}');
        }
      } catch (e) {
        print('Firebase Functions呼び出しエラー: $e');
        // Functions呼び出しが失敗してもチェックイン自体は成功として処理
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('チェックインしました！'),
          duration: Duration(seconds: 2),
        ),
      );

      // タイマーを設定して_showConfirmationをfalseに設定
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showConfirmation = false;
          });
        }
      });
    } catch (error) {
      print('Error during check-in: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('チェックインに失敗しました。'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // 外部ナビゲーションアプリを起動するメソッド（既存の_launchMapsUrlを改良）
  void _launchExternalNavigation(double lat, double lng) async {
    try {
      // 複数のナビゲーションアプリを試行
      List<String> navigationUrls = [];

      if (Platform.isIOS) {
        // iOS用のURL
        navigationUrls.addAll([
          'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d', // Apple Maps
          'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving', // Google Maps iOS
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng', // Web fallback
        ]);
      } else {
        // Android用のURL
        String travelMode = _selectedTravelMode.toLowerCase();
        navigationUrls.addAll([
          'google.navigation:q=$lat,$lng&mode=$travelMode', // Google Maps Navigation
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=$travelMode&dir_action=navigate', // Google Maps Web
        ]);
      }

      // URLを順番に試行
      bool launched = false;
      for (String url in navigationUrls) {
        try {
          if (await canLaunch(url)) {
            await launch(url);
            launched = true;
            break;
          }
        } catch (e) {
          print('Failed to launch $url: $e');
          continue;
        }
      }

      if (!launched) {
        // 最後の手段として座標をクリップボードにコピー
        await Clipboard.setData(ClipboardData(text: '$lat,$lng'));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('座標をクリップボードにコピーしました: $lat,$lng'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error launching navigation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ナビゲーションの起動に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorOccurred
                  ? const Center(child: Text('エラーが発生しました。'))
                  : Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: const CameraPosition(
                            target: LatLng(35.658581, 139.745433),
                            zoom: 16.0,
                            bearing: 30.0,
                            tilt: 60.0,
                          ),
                          markers: _markers,
                          circles: _circles,
                          polylines: _polylines,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          onMapCreated: (GoogleMapController controller) {
                            _mapController = controller;
                            controller.setMapStyle(_mapStyle);
                            _moveToCurrentLocation();

                            // 地図の完全読み込み後のコールバックを設定
                            controller.setMapStyle(_mapStyle).then((_) {
                              // 地図スタイルの適用が完了した後の処理

                              // 初期ズームレベルを設定（オプション）
                              if (_currentPosition != null) {
                                controller.moveCamera(
                                  CameraUpdate.newCameraPosition(
                                    CameraPosition(
                                      target: _currentPosition!,
                                      zoom: 15.0,
                                    ),
                                  ),
                                );
                              }
                            });
                          },
                          onCameraIdle: () {
                            if (_pendingMarkers.isNotEmpty &&
                                !_isLoadingMoreMarkers) {
                              _processMarkerBatch();
                            }
                          },
                        ),

                        // Add the search bar here
                        _buildSearchBar(),

                        // Loading indicators and other UI elements
                        if (_isLoadingMoreMarkers)
                          Positioned(
                            bottom: 70,
                            right: 16,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
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
                                ],
                              ),
                            ),
                          ),

                        Positioned(
                          bottom: 25,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: FloatingActionButton.extended(
                              onPressed: _isLoadingNearbyMarkers
                                  ? null
                                  : _loadNearbyMarkers,
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                                side: BorderSide(color: Colors.white, width: 2),
                              ),
                              icon: Icon(
                                Icons.near_me,
                                color: Colors.white,
                              ),
                              label: Text(
                                '付近を読み込む',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                        if (_isLoadingNearbyMarkers)
                          Positioned(
                            bottom: 210,
                            right: 16,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
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
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
          if (_showConfirmation)
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '✔︎',
                      style: TextStyle(
                        fontSize: 48,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              postData['imageUrl'],
              fit: BoxFit.cover,
              width: double.infinity,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${postData['userDisplayName']} (@${postData['userId']})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(postData['caption']),
                  const SizedBox(height: 8),
                  Text(
                    '投稿日時: ${(postData['timestamp'] as Timestamp).toDate().toString()}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
