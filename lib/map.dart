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
  String _inputValue = '';
  String _resultMessage = '';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 位置情報サービスが有効か確認
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 位置情報サービスが無効の場合の処理
      _showErrorDialog('位置情報サービスが無効です。');
      setState(() {
        _isLoading = false;
        _errorOccurred = true;
      });
      return;
    }

    // 位置情報の許可を確認
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // ユーザーが位置情報の許可を拒否した場合の処理
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
      // ユーザーが位置情報の許可を永続的に拒否した場合の処理
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

    // 位置情報を取得
    final Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _isLoading = false;
    });
    _setCustomMarkers();
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

      // 現在位置のマーカーを追加する
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

  void _showLocationPermissionDialog(
      {String message = '位置情報の許可が必要です。', String actionText = '設定を開く'}) {
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
      "学",
      "ここは大学です。",
    );
    final marker5 = await _createMarkerWithImage(
      const LatLng(34.666535957785, 133.91807787258),
      'assets/images/kamebashi.jpg',
      'marker4',
      150,
      100,
      "岡山駅",
      "ここは岡山駅です",
    );

    setState(() {
      _markers.add(marker1);
      _markers.add(marker2);
      _markers.add(marker3);
      _markers.add(marker4);
      _markers.add(marker5);
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
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(imagePath, width: 150, height: 100),
                      const SizedBox(height: 16),
                      ListTile(
                        title: Text(title),
                        subtitle: Text(snippet),
                      ),
                      const SizedBox(height: 16),
                      if (_canCheckIn)
                        _buildCheckInForm(context, title)
                      else
                        _buildCheckInButton(),
                      const SizedBox(
                        height: 10.0,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCheckInForm(BuildContext context, String title) {
    return Column(
      children: [
        TextField(
          onChanged: (value) {
            setState(() {
              _inputValue = value;
            });
          },
          decoration: const InputDecoration(labelText: '入力してください'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _validateCheckIn(context, title),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text(
            '送信',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInButton() {
    return ElevatedButton(
      onPressed: null,
      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
      child: const Text(
        '対象から離れているためチェックインできません',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  bool _calculateCanCheckIn() {
    if (_currentPosition == null) return false;
    return _distance <= 500.0;
  }

  void _validateCheckIn(BuildContext context, String title) {
    bool isCorrect = _inputValue == title;
    _showCheckInResult(context, isCorrect);
  }

  void _showCheckInResult(BuildContext context, bool isCorrect) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30.0,
                backgroundColor: isCorrect ? Colors.green : Colors.red,
                child: Icon(
                  isCorrect ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 50.0,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 1), () {
      Navigator.of(context).pop();
      _showCheckInMessage(context, isCorrect);
    });
  }

  void _showCheckInMessage(BuildContext context, bool isCorrect) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30.0,
                backgroundColor: isCorrect ? Colors.green : Colors.red,
                child: Icon(
                  isCorrect ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 50.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isCorrect ? 'チェックイン済み' : '入力が間違っています',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 1), () {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    LatLng initialCameraPosition =
        const LatLng(35.658581, 139.745433); // 東京駅の位置

    if (!_isLoading && !_errorOccurred && _currentPosition != null) {
      initialCameraPosition = _currentPosition!;
    }

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorOccurred
              ? const Center(child: Text('エラーが発生しました。'))
              : GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: initialCameraPosition,
                    zoom: 16.0,
                    bearing: 30.0,
                    tilt: 60.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                ),
    );
  }
}
