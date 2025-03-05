import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
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

  // Google Routes API関連の変数
  Map<PolylineId, Polyline> _routePolylines = {};
  String _selectedTravelMode = 'DRIVE'; // 'DRIVE', 'WALK', 'BICYCLE', 'TRANSIT'のいずれか
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

  //緯度と経度から住所を取得するヘルパー関数
  Future<String> _getAddressFromLatLng(
      double latitude,
      double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
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
              FutureBuilder<List<Map<String, dynamic>>>(
                future: Future.wait(_searchResults.map((doc) async {
                  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                  String locationInfo = '';

                  // データに緯度と経度が含まれている場合は住所を取得
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
                      height: 100,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00008b)),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      height: 100,
                      child: Center(child: Text('検索結果がありません')),
                    );
                  }

                  final searchResultsWithAddress = snapshot.data!;

                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    height: min(searchResultsWithAddress.length * 72.0, 300),
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
                        itemCount: searchResultsWithAddress.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey.withOpacity(0.3),
                          indent: 70,
                          endIndent: 20,
                        ),
                        itemBuilder: (context, index) {
                          final data = searchResultsWithAddress[index];
                          final doc = data['doc'] as DocumentSnapshot;
                          final locationInfo = data['locationInfo'] as String;

                          return InkWell(
                            onTap: () {
                              _jumpToLocation(doc);
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
                                          (data['title'] ?? 'No Title') + locationInfo,
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
                                      _jumpToLocation(doc);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
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
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                    Icon(Icons.place, color: Colors.white, size: 20),
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
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onPressed: () async {
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
                              child: Column(
                                children: [
                                  Icon(Icons.visibility, color: Colors.white, size: 20),
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
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                if (_selectedMarker != null) {
                                  _showNavigationModalBottomSheet(context, _selectedMarker!.position);
                                }
                              },
                              child: Column(
                                children: [
                                  Icon(Icons.directions, color: Colors.white, size: 20),
                                  const Text(
                                    'ルート案内',
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
  Future<void> _getRouteWithAPI(LatLng origin, LatLng destination) async {
    if (_isLoadingRoute) return;

    setState(() {
      _isLoadingRoute = true;
      _routeDuration = null;
      _routeDistance = null;
    });

    try {
      // API キーを設定
      final String apiKey = 'YOUR_API_KEY'; // Replace with your actual API key

      // Routes API エンドポイント
      final String url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

      // Routes API リクエストボディを構築
      final Map<String, dynamic> requestBody = {
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
        'travelMode': _selectedTravelMode,
        'routingPreference': 'TRAFFIC_AWARE',
        'computeAlternativeRoutes': false,
        'routeModifiers': {
          'avoidTolls': false,
          'avoidHighways': false,
          'avoidFerries': false
        },
        'languageCode': 'ja-JP',
        'units': 'METRIC'
      };

      // リクエストヘッダーを設定
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs'
      };

      // API リクエストを送信 - タイムアウトを追加
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(requestBody),
      ).timeout(
        Duration(seconds: 15), // 15秒のタイムアウトを設定
        onTimeout: () {
          throw TimeoutException('ルート計算がタイムアウトしました。ネットワーク接続を確認してください。');
        },
      );

      // レスポンスのステータスコードをチェック
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // レスポンス内のroutesキーをチェック
        if (data.containsKey('routes') && data['routes'] is List && data['routes'].isNotEmpty) {
          // ルートを描画
          _drawRouteFromRoutesAPI(data);

          // 所要時間と距離を取得して表示
          _displayRouteSummary(data);
        } else {
          // データは受信できたが、ルート情報が含まれていない
          print('No routes found in the response: $data');
          _showErrorSnackbar('ルートが見つかりませんでした。目的地を変更してみてください。');
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // 認証エラー
        print('Authentication error: ${response.statusCode}, ${response.body}');
        _showErrorSnackbar('APIキーに問題があります。管理者にお問い合わせください。');
      } else if (response.statusCode >= 500) {
        // サーバーエラー
        print('Server error: ${response.statusCode}, ${response.body}');
        _showErrorSnackbar('サーバーエラーが発生しました。後でもう一度お試しください。');
      } else {
        // その他のエラー
        print('Routes API error: ${response.statusCode}, ${response.body}');
        _showErrorSnackbar('ルートの取得に失敗しました (${response.statusCode})');
      }
    } on SocketException catch (e) {
      // ネットワーク接続エラー
      print('Network error: $e');
      _showErrorSnackbar('ネットワーク接続エラー。インターネット接続を確認してください。');
    } on TimeoutException catch (e) {
      // タイムアウトエラー
      print('Timeout error: $e');
      _showErrorSnackbar('ルート計算がタイムアウトしました。ネットワーク接続を確認してください。');
    } on FormatException catch (e) {
      // JSONパースエラー
      print('Data format error: $e');
      _showErrorSnackbar('データ形式エラー。開発者にお問い合わせください。');
    } catch (e) {
      // その他の例外
      print('Error fetching route: $e');
      _showErrorSnackbar('ルートの取得中にエラーが発生しました: ${e.toString().substring(0, min(50, e.toString().length))}');
    } finally {
      // 処理が終了したらローディング状態をリセット
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  // エラーメッセージを表示するヘルパーメソッド
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Routes API のレスポンスからルートを描画するメソッド
  void _drawRouteFromRoutesAPI(Map<String, dynamic> routesData) {
    // 以前のルートをクリア
    setState(() {
      _polylines.clear();
      _routePolylines.clear();
    });

    // レスポンスからエンコードされたポリラインを取得
    final String encodedPolyline = routesData['routes'][0]['polyline']['encodedPolyline'];

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
    final route = routesData['routes'][0];

    // 所要時間を秒から変換
    final int durationSeconds = int.parse(route['duration'].replaceAll('s', ''));
    final Duration duration = Duration(seconds: durationSeconds);

    // 距離をメートルから変換
    final int distanceMeters = route['distanceMeters'];
    final String distanceText = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
        : '$distanceMeters m';

    // 所要時間のフォーマット
    String durationText;
    if (duration.inHours > 0) {
      durationText = '${duration.inHours}時間${(duration.inMinutes % 60)}分';
    } else {
      durationText = '${duration.inMinutes}分';
    }

    // 状態を更新して UI に反映
    setState(() {
      _routeDuration = durationText;
      _routeDistance = distanceText;
    });

    // スナックバーで表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('所要時間: $durationText, 距離: $distanceText'),
        duration: Duration(seconds: 4),
        backgroundColor: Colors.blue.shade700,
      ),
    );
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, color: Color(0xFF00008b)),
                    SizedBox(height: 4),
                    Text(
                      _routeDuration!,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('所要時間', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                VerticalDivider(thickness: 1, width: 30, color: Colors.grey[300]),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.straighten, color: Color(0xFF00008b)),
                    SizedBox(height: 4),
                    Text(
                      _routeDistance!,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('距離', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            // リトライボタンを追加
            OutlinedButton.icon(
              onPressed: () {
                if (_currentPosition != null && _selectedMarker != null) {
                  _getRouteWithAPI(_currentPosition!, _selectedMarker!.position);
                }
              },
              icon: Icon(Icons.refresh, size: 16),
              label: Text('ルートを再計算'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFF00008b),
                side: BorderSide(color: Color(0xFF00008b)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showNavigationModalBottomSheet(BuildContext context, LatLng destination) async {
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
                      _buildTravelModeSelector(),
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
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.directions),
                                onPressed: () {
                                  _launchExternalNavigation(destination.latitude, destination.longitude);
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

  // 外部ナビゲーションアプリを起動するメソッド（既存の_launchMapsUrlを改良）
  void _launchExternalNavigation(double lat, double lng) async {
    String url;

    // iOS と Android で異なる URL スキームを使用
    if (Platform.isIOS) {
      // iOS では Apple Maps または Google Maps を起動
      url = 'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d';
    } else {
      // Android では Google Maps を起動
      String travelMode = 'd'; // デフォルトはドライブモード
      switch (_selectedTravelMode) {
        case 'WALK':
          travelMode = 'w';
          break;
        case 'BICYCLE':
          travelMode = 'b';
          break;
        case 'TRANSIT':
          travelMode = 'r';
          break;
      }
      url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=${_selectedTravelMode.toLowerCase()}&dir_action=navigate';
    }

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      // フォールバックとして Web 版 Google Maps を開く
      final webUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
      if (await canLaunch(webUrl)) {
        await launch(webUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ナビゲーションアプリを開けませんでした')),
        );
      }
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