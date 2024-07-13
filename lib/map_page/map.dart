import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _errorOccurred = false;
  bool _canCheckIn = false;
  bool _showConfirmation = false; // Control confirmation display
  Marker? _selectedMarker;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadMarkersFromFirestore();
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
    });
    _moveToCurrentLocation();
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

      final Marker marker = Marker(
        markerId: const MarkerId('current_position_marker'),
        position: _currentPosition!,
        infoWindow: const InfoWindow(title: '現在位置'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );

      setState(() {
        _markers.add(marker);
      });
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
      String locationId = data['locationID'].toString();
      String title = data['title'];
      String description = data['description'];

      Marker marker = await _createMarkerWithImage(
        position,
        imageUrl,
        locationId,
        150,
        100,
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
      onTap: () {
        setState(() {
          _selectedMarker = Marker(
            markerId: MarkerId(markerId),
            position: position,
            icon: BitmapDescriptor.fromBytes(markerIcon),
          );
          _calculateDistance(position);
          _showModalBottomSheet(context, imageUrl, title, snippet);
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

  void _showModalBottomSheet(
      BuildContext context, String imageUrl, String title, String snippet) {
    TextEditingController textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return ListView(
              shrinkWrap: true,
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    snippet,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (_selectedMarker != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _canCheckIn = true;
                        });
                      },
                      child: const Text('チェックイン'),
                    ),
                  ),
                if (_canCheckIn)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: textController,
                          decoration: InputDecoration(
                            hintText: 'コメントを入力してください',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.text,
                          maxLines: null,
                          textAlign: TextAlign.left,
                          onChanged: (text) {
                            // Handle text changes here
                          },
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            // Handle submission of text
                            String comment = textController.text;
                            // Use 'comment' as needed, e.g., save to Firestore
                            print('コメント: $comment');
                            _showConfirmationDialog(
                                context); // Show confirmation dialog
                          },
                          child: const Text('送信'),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    ).then((value) {
      // This code block executes when the bottom sheet is dismissed
      if (_showConfirmation) {
        Timer(Duration(seconds: 2), () {
          setState(() {
            _showConfirmation = false; // Reset confirmation state
            _canCheckIn = false; // Reset check-in state
          });
        });
      }
    });
  }

  void _showConfirmationDialog(BuildContext context) {
    Navigator.of(context).pop(); // Close the bottom sheet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('チェックインしました！'),
        duration: Duration(seconds: 2),
      ),
    );

    setState(() {
      _showConfirmation = true; // Set confirmation flag
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorOccurred
                  ? const Center(child: Text('エラーが発生しました。'))
                  : GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(35.658581, 139.745433),
                        zoom: 16.0,
                        bearing: 30.0,
                        tilt: 60.0,
                      ),
                      markers: _markers,
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        _moveToCurrentLocation();
                      },
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
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
            ),
          if (_canCheckIn && !_showConfirmation)
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '✖️',
                        style: TextStyle(
                          fontSize: 48,
                          color: Colors.red,
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
