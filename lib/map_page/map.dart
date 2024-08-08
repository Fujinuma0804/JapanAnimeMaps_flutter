import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../PostScreen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = true;
  bool _errorOccurred = false;
  bool _canCheckIn = false;
  bool _showConfirmation = false;
  bool _isCorrect = false;
  bool _hasCheckedInAlready = false;
  Marker? _selectedMarker;
  late User _user;
  late String _userId;
  bool _isFavorite = false;
  bool _isSubmitting = false;

  late VideoPlayerController _videoPlayerController;
  late Future<void> _initializeVideoPlayerFuture;

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
    _getCurrentLocation();
    _loadMarkersFromFirestore();
    _getUser();
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
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

  void _calculateDistance(LatLng markerPosition) {
    if (_currentPosition != null) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        markerPosition.latitude,
        markerPosition.longitude,
      );
      print('Distance: $distance meters');
      setState(() {
        _canCheckIn = distance <= 500;
      });
    }
  }

  Future<void> _loadMarkersFromFirestore() async {
    CollectionReference markers =
        FirebaseFirestore.instance.collection('locations');

    QuerySnapshot snapshot = await markers.get();
    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      double latitude = (data['latitude'] as num).toDouble();
      double longitude = (data['longitude'] as num).toDouble();
      LatLng position = LatLng(latitude, longitude);
      String imageUrl = data['imageUrl'];
      String locationId = doc.id;
      String title = data['title'];
      String description = data['description'];

      Marker marker = await _createMarkerWithImage(
        position,
        imageUrl,
        locationId,
        280,
        180,
        title,
        description,
      );

      setState(() {
        _markers.add(marker);
      });
    }
  }

  Future<Marker> _createMarkerWithImage(
    LatLng position,
    String imageUrl,
    String markerId,
    int width,
    int height,
    String title,
    String snippet,
  ) async {
    final Uint8List markerIcon =
        await _getBytesFromUrl(imageUrl, width, height);

    return Marker(
      markerId: MarkerId(markerId),
      position: position,
      icon: BitmapDescriptor.fromBytes(markerIcon),
      onTap: () async {
        bool hasCheckedIn = await _hasCheckedIn(markerId);
        setState(() {
          _selectedMarker = Marker(
            markerId: MarkerId(markerId),
            position: position,
            icon: BitmapDescriptor.fromBytes(markerIcon),
          );
          _calculateDistance(position);
          _showModalBottomSheet(
              context, imageUrl, title, snippet, hasCheckedIn);
        });
      },
    );
  }

  Future<Uint8List> _getBytesFromUrl(String url, int width, int height) async {
    final http.Response response = await http.get(Uri.parse(url));
    final ui.Codec codec = await ui.instantiateImageCodec(
      response.bodyBytes,
      targetWidth: width,
      targetHeight: height,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  Future<bool> _hasCheckedIn(String locationId) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('check_ins')
        .where('locationId', isEqualTo: locationId)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  void _showModalBottomSheet(BuildContext context, String imageUrl,
      String title, String snippet, bool hasCheckedIn) {
    TextEditingController textController = TextEditingController();
    bool isCorrect = false;
    bool showTextField = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
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
                    Padding(
                      padding: EdgeInsets.all(15),
                      child: Center(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
                                      setState(() {
                                        showTextField = true;
                                      });
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
                            onPressed: () {
                              Navigator.pop(context);
                              _showNavigationModalBottomSheet(
                                  context, _selectedMarker!.position);
                            },
                            child: const Text(
                              'ここへ行く',
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
                    if (_canCheckIn && !hasCheckedIn && showTextField)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: textController,
                              decoration: const InputDecoration(
                                hintText: '題名を入力してください',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.text,
                              maxLines: null,
                              textAlign: TextAlign.left,
                              onChanged: (text) {
                                setState(() {
                                  isCorrect = text.trim().toLowerCase() ==
                                      title.trim().toLowerCase();
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      showTextField = false;
                                    });
                                  },
                                  child: const Text(
                                    '戻る',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isSubmitting
                                        ? Colors.grey
                                        : const Color(0xFF00008b),
                                  ),
                                  onPressed: _isSubmitting
                                      ? null
                                      : () {
                                          String comment = textController.text;
                                          _checkIn(comment, title, isCorrect,
                                              _selectedMarker!.markerId.value);
                                          Navigator.of(context).pop();
                                        },
                                  child: const Text(
                                    '送信',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    // if (hasCheckedIn)
                    //   const Padding(
                    //     padding: EdgeInsets.all(8.0),
                    //     child: Text(
                    //       '✔︎チェックイン済み',
                    //       style: TextStyle(
                    //         fontSize: 16,
                    //         fontWeight: FontWeight.bold,
                    //         color: Colors.grey,
                    //       ),
                    //     ),
                    //   ),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((value) {
      if (_showConfirmation) {
        Timer(const Duration(seconds: 2), () {
          setState(() {
            _showConfirmation = false;
            _canCheckIn = false;
          });
        });
      }
    });
  }

  StreamSubscription<DocumentSnapshot>? _favoriteSubscription;

  void _showNavigationModalBottomSheet(
      BuildContext context, LatLng destination) async {
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
                            onPressed: () {},
                          ),
                          const Text('その他'),
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
                                    locationId: _selectedMarker!.markerId.value,
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

  void _checkIn(
      String comment, String title, bool isCorrect, String locationId) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('check_ins')
          .add({
        'title': title,
        'comment': comment,
        'isCorrect': isCorrect,
        'locationId': locationId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      DocumentReference locationRef =
          FirebaseFirestore.instance.collection('locations').doc(locationId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(locationRef);

        if (snapshot.exists) {
          int currentCount =
              (snapshot.data() as Map<String, dynamic>)['checkinCount'] ?? 0;
          transaction.update(locationRef, {'checkinCount': currentCount + 1});
        } else {
          print('Location document does not exist: $locationId');
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCorrect ? 'チェックインしました！' : '題名が異なります。'),
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {
        _showConfirmation = true;
        _isCorrect = isCorrect;
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
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _isCorrect ? '✔︎' : '❌',
                        style: TextStyle(
                          fontSize: 48,
                          color: _isCorrect ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
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
