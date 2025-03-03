import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:parts/map_page/background_location.dart';
import 'package:parts/map_page/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../PostScreen.dart';
import '../spot_page/anime_list_detail.dart';

class MapSubscription extends StatefulWidget {
  const MapSubscription(
      {Key? key, required double longitude, required double latitude})
      : super(key: key);

  @override
  State<MapSubscription> createState() => _MapSubscriptionState();
}

class _MapSubscriptionState extends State<MapSubscription> {
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

  TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  FocusNode _searchFocusNode = FocusNode();

  late VideoPlayerController _videoPlayerController;
  late Future<void> _initializeVideoPlayerFuture;

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
    NotificationService.initialize();
    LocationService.initialize();
    _getCurrentLocation();
    _loadMarkersFromFirestore();
    _getUser();
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getUser() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    _user = auth.currentUser!;
    _userId = _user.uid;
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

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Search in locations collection
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(5)
          .get();

      // If no results, also search in anime names
      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('locations')
            .where('animeName', isGreaterThanOrEqualTo: query)
            .where('animeName', isLessThanOrEqualTo: query + '\uf8ff')
            .limit(5)
            .get();
      }

      setState(() {
        _searchResults = snapshot.docs;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

// マーカー表示を含め、変数名のエラーを修正したjumpToLocationメソッド
  void _jumpToLocation(DocumentSnapshot locationDoc) async {
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
    bool markerExists = _markers.any((marker) => marker.markerId.value == locationId);

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
        _selectedMarker = _markers.firstWhere((marker) => marker.markerId.value == locationId);
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
          _circles.removeWhere((circle) => circle.circleId.value == 'highlight_$locationId');
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
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 15,
      right: 15,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
              offset: Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'スポットまたはアニメ名を検索',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Container(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.search,
                      color: Color(0xFF00008b),
                      size: 22,
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? Container(
                    padding: EdgeInsets.all(8),
                    child: AnimatedOpacity(
                      opacity: _searchController.text.isNotEmpty ? 1.0 : 0.0,
                      duration: Duration(milliseconds: 200),
                      child: IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[500],
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                          FocusScope.of(context).unfocus();
                        },
                        splashRadius: 20,
                      ),
                    ),
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 5),
                ),
                onChanged: (value) {
                  _performSearch(value);
                },
              ),
            ),
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: _isSearching ? 4 : 0,
              child: _isSearching
                  ? LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00008b)),
              )
                  : null,
            ),
            if (_searchResults.isNotEmpty)
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                height: min(_searchResults.length * 72.0, 300),
                constraints: BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.only(top: 8, bottom: 8),
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey.withOpacity(0.3),
                      indent: 70,
                      endIndent: 20,
                    ),
                    itemBuilder: (context, index) {
                      Map<String, dynamic> data = _searchResults[index].data() as Map<String, dynamic>;
                      return InkWell(
                        onTap: () {
                          _jumpToLocation(_searchResults[index]);
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(25),
                                  child: data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                                      ? Image.network(
                                    data['imageUrl'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Color(0xFF00008b),
                                        child: Icon(Icons.location_on, color: Colors.white, size: 24),
                                      );
                                    },
                                  )
                                      : Container(
                                    color: Color(0xFF00008b),
                                    child: Icon(Icons.location_on, color: Colors.white, size: 24),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['title'] ?? 'No Title',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (data['animeName'] != null && data['animeName'].toString().isNotEmpty)
                                      Text(
                                        data['animeName'],
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey[400],
                                  size: 14,
                                ),
                                onPressed: () {
                                  _jumpToLocation(_searchResults[index]);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
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
      builder: (context) =>
          AlertDialog(
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
      builder: (context) =>
          AlertDialog(
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
          String locationName = (doc.data() as Map<String, dynamic>)['title'] ??
              '';
          bool hasCheckedIn = await _hasCheckedIn(
              _selectedMarker!.markerId.value);

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
      CollectionReference locations = FirebaseFirestore.instance.collection(
          'locations');

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
              visibleRegion.southwest.latitude) / 2,
          (visibleRegion.northeast.longitude +
              visibleRegion.southwest.longitude) / 2
      );

      // 表示範囲の半径をメートル単位で計算
      double distanceInMeters = Geolocator.distanceBetween(
          visibleRegion.northeast.latitude,
          visibleRegion.northeast.longitude,
          visibleRegion.southwest.latitude,
          visibleRegion.southwest.longitude
      ) / 2;

      // 範囲内の位置情報を取得
      CollectionReference locations = FirebaseFirestore.instance.collection(
          'locations');
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
        double? lat = data['latitude'] is num ? (data['latitude'] as num)
            .toDouble() : null;
        double? lng = data['longitude'] is num ? (data['longitude'] as num)
            .toDouble() : null;

        // 有効な座標が取得できなかった場合はスキップ
        if (lat == null || lng == null) {
          continue;
        }

        double distance = Geolocator.distanceBetween(
            center.latitude, center.longitude, lat, lng
        );

        // このマーカーが既にマップ上にあるかチェック
        bool alreadyExists = _markers.any((marker) =>
        marker.markerId.value == doc.id
        );

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

      markerFutures.add(
          _createMarkerWithImage(
            position,
            imageUrl,
            locationId,
            300,
            200,
            title,
            animeName,
            description,
          )
      );
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


  Future<Marker?> _createMarkerWithImage(LatLng position,
      String imageUrl,
      String markerId,
      int width,
      int height,
      String title,
      String animeName,
      String snippet,) async {
    try {
      final Uint8List markerIcon = await _getBytesFromUrl(
          imageUrl, width, height);

      // Use compute to move image processing to a separate isolate
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint = Paint()
        ..color = Colors.white;

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

      final img = await pictureRecorder.endRecording().toImage(
          width + 40, height + 60);
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
      final ByteData? byteData = await fi.image.toByteData(
          format: ui.ImageByteFormat.png);

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

// ... [previous code remains the same until _showModalBottomSheet method]

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
                    bottom: MediaQuery
                        .of(context)
                        .viewInsets
                        .bottom),
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
                          if (hasCheckedIn)
                            const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: Text(
                                '✔︎チェックイン済み',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _canCheckIn
                                    ? const Color(0xFF00008b)
                                    : Colors.grey,
                              ),
                              onPressed: _canCheckIn
                                  ? () {
                                _checkIn(title,
                                    _selectedMarker!.markerId.value);
                                Navigator.pop(context);
                              }
                                  : null,
                              child: const Text(
                                'チェックイン',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00008b),
                            ),
                            onPressed: () async {
                              // 選択されたマーカーのデータを取得
                              DocumentSnapshot snapshot = await FirebaseFirestore
                                  .instance
                                  .collection('locations')
                                  .doc(_selectedMarker!.markerId.value)
                                  .get();

                              if (snapshot.exists) {
                                Map<String, dynamic> data = snapshot
                                    .data() as Map<String, dynamic>;

                                // subMediaの処理
                                List<Map<String, dynamic>> subMediaList = [];
                                if (data['subMedia'] != null &&
                                    data['subMedia'] is List) {
                                  subMediaList =
                                      (data['subMedia'] as List).map((item) {
                                        return {
                                          'type': item['type'] as String? ?? '',
                                          'url': item['url'] as String? ?? '',
                                          'title': item['title'] as String? ??
                                              '',
                                        };
                                      }).toList();
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SpotDetailScreen(
                                          title: data['title'] ?? '',
                                          description: data['description'] ??
                                              '',
                                          spot_description: data['spot_description'] ??
                                              '',
                                          latitude: data['latitude'] != null
                                              ? (data['latitude'] as num)
                                              .toDouble()
                                              : 0.0,
                                          longitude: data['longitude'] != null
                                              ? (data['longitude'] as num)
                                              .toDouble()
                                              : 0.0,
                                          imageUrl: data['imageUrl'] ?? '',
                                          sourceTitle: data['sourceTitle'] ??
                                              '',
                                          subsourceTitle: data['subsourceTitle'] ??
                                              '',
                                          sourceLink: data['sourceLink'] ?? '',
                                          subsourceLink: data['subsourceLink'] ??
                                              '',
                                          url: data['url'] ?? '',
                                          subMedia: subMediaList,
                                          locationId: _selectedMarker!.markerId
                                              .value,
                                          animeName: data['animeName'] ?? '',
                                          userId: data['userId'] ?? '',
                                        ),
                                  ),
                                );
                              }
                            },
                            //アプリバージョンver3.0.5までは、押下すると画像の投稿などのページへ遷移する。
                            // onPressed: () {
                            //   Navigator.pop(context);
                            //   _showNavigationModalBottomSheet(
                            //       context, _selectedMarker!.position);
                            // },
                            child: const Text(
                              'スポットを見る',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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

// ... [rest of the code remains the same]
  StreamSubscription<DocumentSnapshot>? _favoriteSubscription;

  void _showNavigationModalBottomSheet(BuildContext context,
      LatLng destination) async {
    // Firebase Firestoreのリスナーを設定
    _favoriteSubscription = FirebaseFirestore.instance
        .collection('favorites') // コレクション名を適宜変更
        .doc(_selectedMarker!.markerId.value) // ドキュメントIDを使用
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _isFavorite = snapshot['isFavorite'];
        });
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.directions),
                            onPressed: () {
                              _launchMapsUrl(
                                  destination.latitude, destination.longitude);
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
                                Map<String, dynamic>? data =
                                snapshot.data() as Map<String, dynamic>?;
                                if (data != null) {
                                  // subMediaの処理を追加
                                  List<Map<String, dynamic>> subMediaList = [];
                                  if (data['subMedia'] != null &&
                                      data['subMedia'] is List) {
                                    subMediaList =
                                        (data['subMedia'] as List).map((item) {
                                          return {
                                            'type': item['type'] as String? ??
                                                '',
                                            'url': item['url'] as String? ?? '',
                                            'title': item['title'] as String? ??
                                                '',
                                          };
                                        }).toList();
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SpotDetailScreen(
                                            locationId:
                                            _selectedMarker!.markerId.value,
                                            title: data['title'] ?? '',
                                            description: data['description'] ??
                                                '',
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
                                            sourceTitle: data['sourceTitle'] ??
                                                '',
                                            sourceLink: data['sourceLink'] ??
                                                '',
                                            url: data['url'] ?? '',
                                            subMedia: subMediaList,
                                            animeName: '',
                                            userId: '',
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
                                  builder: (context) =>
                                      PostScreen(
                                        locationId: _selectedMarker!.markerId
                                            .value,
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
                                Map<String, dynamic>? data =
                                snapshot.data() as Map<String, dynamic>?;
                                if (data != null &&
                                    data.containsKey('sourceLink')) {
                                  final String sourceLink = data['sourceLink'];
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
                              _toggleFavorite(_selectedMarker!.markerId.value);
                            },
                          ),
                          const Text('お気に入り'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getPostedImages(_selectedMarker!.markerId.value),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
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
                                    builder: (context) =>
                                        PostDetailScreen(
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
    ).whenComplete(() {
      // モーダルが閉じたときにリスナーを解除
      _favoriteSubscription?.cancel();
    });

    _showRouteOnMap(destination);
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
        String fileName = '${DateTime
            .now()
            .millisecondsSinceEpoch}.jpg';
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

// [Previous imports and code remain exactly the same until the _checkIn method]

  void _checkIn(String title, String locationId) async {
    setState(() {
      _isSubmitting = true;
      _showConfirmation = true;
    });

    try {
      // 既存のチェックイン記録を追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('check_ins')
          .add({
        'title': title,
        'locationId': locationId,
        'timestamp': FieldValue.serverTimestamp(),
      });

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

// [Rest of the code remains exactly the same]
  void _launchMapsUrl(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _showRouteOnMap(LatLng destination) {
    if (_currentPosition != null) {
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId("route"),
            points: [_currentPosition!, destination],
            color: Colors.blue,
            width: 5,
          ),
        );
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              _currentPosition!.latitude < destination.latitude
                  ? _currentPosition!.latitude
                  : destination.latitude,
              _currentPosition!.longitude < destination.longitude
                  ? _currentPosition!.longitude
                  : destination.longitude,
            ),
            northeast: LatLng(
              _currentPosition!.latitude > destination.latitude
                  ? _currentPosition!.latitude
                  : destination.latitude,
              _currentPosition!.longitude > destination.longitude
                  ? _currentPosition!.longitude
                  : destination.longitude,
            ),
          ),
          100.0,
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
                },
                onCameraIdle: () {
                  if (_pendingMarkers.isNotEmpty && !_isLoadingMoreMarkers) {
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
                      side: BorderSide(
                          color: Colors.white,
                          width: 2),
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
