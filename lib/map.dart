import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException, rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  double _distance = 0.0;
  bool _isLoading = true;
  bool _errorOccurred = false;
  bool _canCheckIn = false;
  Marker? _selectedMarker;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _setCustomMarkers();
      _moveToCurrentLocation();
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        _showLocationPermissionDialog();
      } else if (e.code == 'PERMISSION_DENIED_NEVER_ASK') {
        _showLocationPermissionDialog(
          message: '位置情報がオフになっています。設定アプリケーションで位置情報をオンにしてください。',
          actionText: '設定を開く',
        );
      } else {
        _showErrorDialog('位置情報を取得できませんでした。');
      }
      setState(() {
        _isLoading = false;
        _errorOccurred = true;
      });
    }
  }

  void _moveToCurrentLocation() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition!,
            zoom: 15.0,
          ),
        ),
      );
    }
  }

  void _showLocationPermissionDialog(
      {String message = '', String actionText = ''}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('位置情報の許可が必要です'),
        content: Text(message.isNotEmpty
            ? message
            : '位置情報の使用を許可していないため、現在位置を取得できませんでした。'),
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
            child: Text(actionText.isNotEmpty ? actionText : '設定を開く'),
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
      _distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        markerPosition.latitude,
        markerPosition.longitude,
      );
    }
  }

  Future<void> _setCustomMarkers() async {
    final marker1 = await _createMarkerWithImage(
      const LatLng(35.658581, 139.745433),
      'assets/images/kamebashi.jpg',
      'marker1',
      150,
      100,
      "ミナ.クル前(1話)",
      "夜のお楽しみ会で通る場所。七尾出身の絵師「長谷川等伯」像と同じポーズでバシャリ。",
    );
    final marker2 = await _createMarkerWithImage(
      const LatLng(35.659581, 139.746433),
      'assets/images/kamebashi.jpg',
      'marker2',
      150,
      100,
      "タイトル2",
      "説明文2",
    );
    final marker3 = await _createMarkerWithImage(
      const LatLng(34.68887729, 133.93229229),
      'assets/images/kamebashi.jpg',
      'marker3',
      150,
      100,
      "お家だよ〜〜",
      "テストテストMyHouse",
    );
    final marker4 = await _createMarkerWithImage(
      const LatLng(34.69615058, 133.92786637),
      'assets/images/kamebashi.jpg',
      'marker4',
      150,
      100,
      "岡山理科大学",
      "ここは岡山理科大学です。",
    );

    setState(() {
      _markers.add(marker1);
      _markers.add(marker2);
      _markers.add(marker3);
      _markers.add(marker4);
    });
  }

  Future<Marker> _createMarkerWithImage(
    LatLng position,
    String imagePath,
    String markerId,
    int width,
    int height,
    String title,
    String snippet,
  ) async {
    final Uint8List markerIcon =
        await _getBytesFromAsset(imagePath, width, height);
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
          _canCheckIn = _calculateCanCheckIn();
        });
        _showModalBottomSheet(context, imagePath, title, snippet);
      },
    );
  }

  Future<Uint8List> _getBytesFromAsset(
      String path, int width, int height) async {
    final ByteData data = await rootBundle.load(path);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
      targetHeight: height,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  void _showModalBottomSheet(
      BuildContext context, String imagePath, String title, String snippet) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Image.asset(imagePath, width: 150, height: 100),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(title),
                    subtitle: Text(snippet),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _canCheckIn ? () => _checkIn() : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canCheckIn ? Colors.green : Colors.grey,
                    ),
                    child: Text(
                      _canCheckIn ? '✔︎ チェックイン' : '対象から離れているためチェックインできません',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Text('距離: ${_distance.toStringAsFixed(2)} メートル'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _calculateCanCheckIn() {
    if (_currentPosition == null) return false;
    return _distance < 1000; // 1000メートル以内であればチェックイン可能
  }

  void _checkIn() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('チェックインしました'),
        content: const Text('現在位置にチェックインしました。'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition ??
                    LatLng(35.681236, 139.767125), // デフォルトは東京駅
                zoom: 15,
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _moveToCurrentLocation();
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _markers,
            ),
    );
  }
}
