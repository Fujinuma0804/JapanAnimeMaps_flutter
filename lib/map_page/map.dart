import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

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
  bool _isLoading = true;
  bool _errorOccurred = false;
  bool _canCheckIn = false;
  bool _showConfirmation = false;
  bool _isCorrect = false;
  bool _hasCheckedInAlready = false;
  Marker? _selectedMarker;
  late User _user;
  late String _userId;
  bool _isSubmitting = false;

  late VideoPlayerController _videoPlayerController;
  late Future<void> _initializeVideoPlayerFuture;

  static const String _mapStyle = '''
  [
    {
      "featureType": "all",
      "elementType": "labels",
      "stylers": [
        { "visibility": "off" }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels",
      "stylers": [
        { "visibility": "on" }
      ]
    },
    {
      "featureType": "transit.station",
      "elementType": "labels",
      "stylers": [
        { "visibility": "on" }
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
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    _videoPlayerController = VideoPlayerController.network(
        'https://firebasestorage.googleapis.com/v0/b/anime-97d2d.appspot.com/o/sky5.mp4?alt=media&token=a1148d51-4b7b-4667-acfe-31cffc9991ab');
    _initializeVideoPlayerFuture =
        _videoPlayerController.initialize().then((_) {
      _videoPlayerController.setLooping(true);
      _videoPlayerController.setVolume(0.0);
      _videoPlayerController.play();
      setState(() {});
    });
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
      LatLng position = LatLng(data['latitude'], data['longitude']);
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
                    Center(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: Text(
                          snippet,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    if (_selectedMarker != null &&
                        !hasCheckedIn &&
                        !showTextField)
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton(
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
                          ),
                          if (!_canCheckIn)
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
                          const SizedBox(height: 15.0),
                        ],
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
                      ),
                    if (hasCheckedIn)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          '✔︎チェックイン済み',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    const SizedBox(height: 15.0),
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
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          onMapCreated: (GoogleMapController controller) {
                            _mapController = controller;
                            controller.setMapStyle(_mapStyle);
                            _moveToCurrentLocation();
                          },
                        ),
                        FutureBuilder(
                          future: _initializeVideoPlayerFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              return Positioned.fill(
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: 0.4,
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: _videoPlayerController
                                            .value.size.width,
                                        height: _videoPlayerController
                                            .value.size.height,
                                        child:
                                            VideoPlayer(_videoPlayerController),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return const SizedBox.shrink();
                            }
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
