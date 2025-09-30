import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class CameraTopScreen extends StatefulWidget {
  const CameraTopScreen({Key? key}) : super(key: key);

  @override
  State<CameraTopScreen> createState() => _CameraTopScreenState();
}

class _CameraTopScreenState extends State<CameraTopScreen> with WidgetsBindingObserver {
  // Method Channel for Swift integration
  static const MethodChannel _cameraChannel = MethodChannel('com.jam.camera/native_camera');
  static const EventChannel _previewChannel = EventChannel('com.jam.camera/camera_preview');

  bool _isInitialized = false;
  bool _isRecording = false;
  String _selectedMode = '写真';
  int _selectedCameraIndex = 0;
  bool _isFlashOn = false;
  double _currentZoom = 1.0;

  // フォーカス関連
  bool _isFocusVisible = false;
  double _focusX = 0;
  double _focusY = 0;
  Timer? _focusTimer;

  // 露出調整関連
  bool _isExposureVisible = false;
  double _exposureValue = 0.0;
  double _minExposureValue = -2.0;
  double _maxExposureValue = 2.0;
  double _exposureSliderY = 0.0;
  bool _isExposureOnRight = true;

  // 位置情報関連
  Position? _currentPosition;
  String _locationStatus = "位置情報を取得中...";
  StreamSubscription<Position>? _positionStream;
  Timer? _locationDebouncer;

  // 最寄りの位置情報関連
  List<Map<String, dynamic>> _nearestLocations = [];
  String _nearestLocationStatus = "最寄り位置を検索中...";
  List<Map<String, dynamic>>? _cachedLocations;
  DateTime? _lastLocationFetch;

  // 画像スライダー関連
  late PageController _imagePageController;
  bool _showImageSlider = false;
  List<String> _nearestImageUrls = [];
  Set<String> _preloadedImages = {};

  // ドラッグ可能な画像関連
  bool _showDraggableImage = false;
  String _currentDraggableImageUrl = '';
  double _draggableImageX = 0;
  double _draggableImageY = 0;
  double _draggableImageScale = 1.0;
  bool _isDragging = false;
  bool _isScaleMode = false;
  Timer? _longPressTimer;
  double _draggableImageWidth = 200.0;
  double _draggableImageHeight = 200.0;

  // カメラプレビュー用のWidgetId
  int? _textureId;

  static const double _focusSize = 80.0;
  static const double _exposureBarHeight = 200.0;
  static const Duration _locationCacheTimeout = Duration(minutes: 5);
  static const Duration _locationDebounceDelay = Duration(seconds: 2);

  final List<String> _cameraModes = ['ビデオ', '写真'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _imagePageController = PageController();

    _checkInitialPermissions();
    _initializeNativeCamera();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _initializeLocation();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _resumeCamera();
    }
  }

  // ネイティブカメラの初期化
  Future<void> _initializeNativeCamera() async {
    try {
      // Swift側でカメラを初期化
      final result = await _cameraChannel.invokeMethod('initializeCamera', {
        'cameraPosition': _selectedCameraIndex == 0 ? 'back' : 'front',
        'resolution': 'high',
      });

      if (result['success'] == true) {
        _textureId = result['textureId'];

        setState(() {
          _isInitialized = true;
        });

        // カメラの設定情報を取得
        await _getCameraCapabilities();

        print('ネイティブカメラ初期化成功: textureId=$_textureId');
      } else {
        throw Exception(result['error'] ?? 'カメラ初期化失敗');
      }
    } catch (e) {
      print('ネイティブカメラ初期化エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('カメラの初期化に失敗しました: $e')),
        );
      }
    }
  }

  // カメラの性能情報を取得
  Future<void> _getCameraCapabilities() async {
    try {
      final capabilities = await _cameraChannel.invokeMethod('getCameraCapabilities');

      _minExposureValue = capabilities['minExposure']?.toDouble() ?? -2.0;
      _maxExposureValue = capabilities['maxExposure']?.toDouble() ?? 2.0;

      print('カメラ性能情報: minExp=$_minExposureValue, maxExp=$_maxExposureValue');
    } catch (e) {
      print('カメラ性能取得エラー: $e');
    }
  }

  // カメラを一時停止
  Future<void> _pauseCamera() async {
    try {
      await _cameraChannel.invokeMethod('pauseCamera');
    } catch (e) {
      print('カメラ一時停止エラー: $e');
    }
  }

  // カメラを再開
  Future<void> _resumeCamera() async {
    try {
      await _cameraChannel.invokeMethod('resumeCamera');
    } catch (e) {
      print('カメラ再開エラー: $e');
    }
  }

  // カメラを切り替え
  Future<void> _switchCamera() async {
    try {
      _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;
      final cameraPosition = _selectedCameraIndex == 0 ? 'back' : 'front';

      await _cameraChannel.invokeMethod('switchCamera', {
        'cameraPosition': cameraPosition,
      });

      await _getCameraCapabilities();
    } catch (e) {
      print('カメラ切り替えエラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('カメラの切り替えに失敗しました: $e')),
      );
    }
  }

  // フラッシュを切り替え
  Future<void> _toggleFlash() async {
    try {
      _isFlashOn = !_isFlashOn;
      await _cameraChannel.invokeMethod('setFlashMode', {
        'flashMode': _isFlashOn ? 'on' : 'off',
      });
      setState(() {});
    } catch (e) {
      print('フラッシュ切り替えエラー: $e');
    }
  }

  // フォーカス設定
  Future<void> _setFocus(Offset point) async {
    try {
      final size = MediaQuery.of(context).size;
      final focusPoint = {
        'x': point.dx / size.width,
        'y': point.dy / size.height,
      };

      await _cameraChannel.invokeMethod('setFocusPoint', focusPoint);

      setState(() {
        _focusX = point.dx;
        _focusY = point.dy;
        _isFocusVisible = true;
        _isExposureVisible = true;
        _exposureValue = 0.0;
        _exposureSliderY = _exposureBarHeight / 2;
        _isExposureOnRight = point.dx < size.width / 2;
      });

      _startFocusTimer();
    } catch (e) {
      print('フォーカス設定エラー: $e');
    }
  }

  // 露出調整
  Future<void> _updateExposure(double deltaY) async {
    if (!_isExposureVisible) return;

    try {
      final exposureChange = -deltaY / 50.0;
      final newExposureValue = (_exposureValue + exposureChange)
          .clamp(_minExposureValue, _maxExposureValue);

      await _cameraChannel.invokeMethod('setExposureOffset', {
        'offset': newExposureValue,
      });

      final newSliderY = (_exposureSliderY + deltaY).clamp(0.0, _exposureBarHeight);

      setState(() {
        _exposureValue = newExposureValue;
        _exposureSliderY = newSliderY;
      });

      _startFocusTimer();
    } catch (e) {
      print('露出調整エラー: $e');
    }
  }

  // ズーム設定
  Future<void> _setZoom(double zoomLevel) async {
    try {
      await _cameraChannel.invokeMethod('setZoomLevel', {
        'zoomLevel': zoomLevel.clamp(1.0, 10.0),
      });

      setState(() {
        _currentZoom = zoomLevel.clamp(1.0, 10.0);
      });
    } catch (e) {
      print('ズーム設定エラー: $e');
    }
  }

  // 写真撮影（合成機能付き）
  Future<void> _captureCompositePhoto() async {
    try {
      print('=== Swift側で合成写真撮影開始 ===');

      // ドラッグ画像の情報を準備
      Map<String, dynamic> overlayInfo = {};
      if (_showDraggableImage && _currentDraggableImageUrl.isNotEmpty) {
        overlayInfo = {
          'hasOverlay': true,
          'imageUrl': _currentDraggableImageUrl,
          'x': _draggableImageX,
          'y': _draggableImageY,
          'width': _draggableImageWidth * _draggableImageScale,
          'height': _draggableImageHeight * _draggableImageScale,
          'scale': _draggableImageScale,
        };
      } else {
        overlayInfo = {'hasOverlay': false};
      }

      // 位置情報を準備
      Map<String, dynamic> locationInfo = {};
      if (_currentPosition != null) {
        locationInfo = {
          'hasLocation': true,
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'timestamp': _currentPosition!.timestamp?.millisecondsSinceEpoch,
        };
      } else {
        locationInfo = {'hasLocation': false};
      }

      // Swift側で写真撮影と合成を実行
      final result = await _cameraChannel.invokeMethod('captureCompositePhoto', {
        'overlay': overlayInfo,
        'location': locationInfo,
        'quality': 100,
      });

      if (result['success'] == true) {
        final imagePath = result['imagePath'] as String;

        // フォトライブラリに保存
        bool hasPermission = await _checkPhotosPermission();
        if (hasPermission) {
          final saveResult = await ImageGallerySaver.saveFile(
            imagePath,
            name: 'JAM_composite_${DateTime.now().millisecondsSinceEpoch}',
          );

          if (saveResult['isSuccess'] == true) {
            String locationText = _currentPosition != null ? ' 位置情報付き' : '';
            String compositeText = _showDraggableImage ? '\n重畳画像あり' : '';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('合成写真をフォトライブラリに保存しました$locationText$compositeText'),
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('保存エラー: ${saveResult['errorMessage'] ?? '不明なエラー'}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('フォトライブラリの権限がないため、アプリ内フォルダに保存されました'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception(result['error'] ?? '撮影失敗');
      }
    } catch (e) {
      print('合成写真撮影エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('撮影エラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 通常写真撮影
  Future<void> _capturePhoto() async {
    try {
      print('=== Swift側で通常写真撮影開始 ===');

      final result = await _cameraChannel.invokeMethod('capturePhoto', {
        'quality': 100,
      });

      if (result['success'] == true) {
        final imagePath = result['imagePath'] as String;

        bool hasPermission = await _checkPhotosPermission();
        if (hasPermission) {
          final saveResult = await ImageGallerySaver.saveFile(
            imagePath,
            name: 'JAM_photo_${DateTime.now().millisecondsSinceEpoch}',
          );

          if (saveResult['isSuccess'] == true) {
            String locationText = _currentPosition != null ? ' 位置情報付き' : '';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('写真をフォトライブラリに保存しました$locationText'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        throw Exception(result['error'] ?? '撮影失敗');
      }
    } catch (e) {
      print('写真撮影エラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('撮影エラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 動画撮影開始
  Future<void> _startVideoRecording() async {
    try {
      final result = await _cameraChannel.invokeMethod('startVideoRecording');

      if (result['success'] == true) {
        setState(() {
          _isRecording = true;
        });
      } else {
        throw Exception(result['error'] ?? '録画開始失敗');
      }
    } catch (e) {
      print('動画撮影開始エラー: $e');
    }
  }

  // 動画撮影停止
  Future<void> _stopVideoRecording() async {
    try {
      final result = await _cameraChannel.invokeMethod('stopVideoRecording');

      if (result['success'] == true) {
        setState(() {
          _isRecording = false;
        });

        final videoPath = result['videoPath'] as String;
        bool hasPermission = await _checkPhotosPermission();

        if (hasPermission) {
          final saveResult = await ImageGallerySaver.saveFile(
            videoPath,
            name: 'JAM_video_${DateTime.now().millisecondsSinceEpoch}',
          );

          if (saveResult['isSuccess'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('動画をフォトライブラリに保存しました')),
            );
          }
        }
      } else {
        throw Exception(result['error'] ?? '録画停止失敗');
      }
    } catch (e) {
      print('動画撮影停止エラー: $e');
    }
  }

  // 権限チェック関連の既存メソッドはそのまま使用
  Future<void> _checkInitialPermissions() async {
    try {
      var cameraStatus = await Permission.camera.status;
      if (cameraStatus.isDenied) {
        cameraStatus = await Permission.camera.request();
      }

      var microphoneStatus = await Permission.microphone.status;
      if (microphoneStatus.isDenied) {
        microphoneStatus = await Permission.microphone.request();
      }

      var locationStatus = await Permission.locationWhenInUse.status;
      if (locationStatus.isDenied) {
        locationStatus = await Permission.locationWhenInUse.request();
      }

      print('初期権限チェック完了');
      print('カメラ: ${cameraStatus.isGranted}');
      print('マイク: ${microphoneStatus.isGranted}');
      print('位置情報: ${locationStatus.isGranted}');

    } catch (e) {
      print('初期権限チェックエラー: $e');
    }
  }

  Future<bool> _checkPhotosPermission() async {
    try {
      print('=== フォトライブラリ権限チェック開始 ===');

      var addOnlyStatus = await Permission.photosAddOnly.status;
      var photosStatus = await Permission.photos.status;

      print('初期 photosAddOnly status: $addOnlyStatus');
      print('初期 photos status: $photosStatus');

      if (addOnlyStatus.isGranted || photosStatus.isGranted) {
        print('権限が既に許可されています');
        return true;
      }

      if (addOnlyStatus.isDenied) {
        print('photosAddOnly権限をリクエスト中...');
        addOnlyStatus = await Permission.photosAddOnly.request();
        print('photosAddOnly request result: $addOnlyStatus');

        if (addOnlyStatus.isGranted) {
          print('photosAddOnly権限が許可されました');
          return true;
        }
      }

      if (photosStatus.isDenied) {
        print('photos権限をリクエスト中...');
        photosStatus = await Permission.photos.request();
        print('photos request result: $photosStatus');

        if (photosStatus.isGranted) {
          print('photos権限が許可されました');
          return true;
        }
      }

      print('すべての権限リクエストが失敗しました');
      return false;

    } catch (e) {
      print('権限チェック中にエラーが発生: $e');
      return false;
    }
  }

  // 位置情報関連の既存メソッドもそのまま使用
  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = "位置情報サービスが無効です";
          _nearestLocationStatus = "位置情報サービスが無効のため検索できません";
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = "位置情報の権限が拒否されました";
            _nearestLocationStatus = "位置情報の権限が拒否されました";
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = "位置情報の権限が永続的に拒否されました";
          _nearestLocationStatus = "位置情報の権限が永続的に拒否されました";
        });
        return;
      }

      await _getCurrentLocation();
      _startLocationStream();
    } catch (e) {
      print('位置情報初期化エラー: $e');
      setState(() {
        _locationStatus = "位置情報の取得に失敗しました: $e";
        _nearestLocationStatus = "位置情報の取得に失敗しました";
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _currentPosition = position;
        _locationStatus = "位置情報を取得しました";
      });

      _locationDebouncer?.cancel();
      _locationDebouncer = Timer(_locationDebounceDelay, () {
        if (mounted) {
          _findNearestLocations(position);
        }
      });
    } catch (e) {
      print('位置情報取得エラー: $e');
      setState(() {
        _locationStatus = "位置情報の取得に失敗: $e";
        _nearestLocationStatus = "現在地取得失敗のため検索できません";
      });
    }
  }

  void _startLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
          (Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            _locationStatus = "位置情報を更新しました";
          });

          _locationDebouncer?.cancel();
          _locationDebouncer = Timer(_locationDebounceDelay, () {
            if (mounted) {
              _findNearestLocations(position);
            }
          });
        }
      },
      onError: (error) {
        print('位置情報ストリームエラー: $error');
        if (mounted) {
          setState(() {
            _locationStatus = "位置情報の更新に失敗: $error";
            _nearestLocationStatus = "位置情報更新失敗";
          });
        }
      },
    );
  }

  Future<void> _findNearestLocations(Position currentPosition) async {
    try {
      if (_cachedLocations != null &&
          _lastLocationFetch != null &&
          DateTime.now().difference(_lastLocationFetch!) < _locationCacheTimeout) {
        print('キャッシュされた位置データを使用');
        _processLocationData(_cachedLocations!, currentPosition);
        return;
      }

      setState(() {
        _nearestLocationStatus = "最寄り位置を検索中...";
      });

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .limit(50)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _nearestLocationStatus = "位置データが見つかりません";
          _nearestLocations = [];
          _nearestImageUrls = [];
          _showImageSlider = false;
        });
        return;
      }

      _cachedLocations = snapshot.docs.map((doc) => {
        'id': doc.id,
        'data': doc.data() as Map<String, dynamic>,
      }).toList();
      _lastLocationFetch = DateTime.now();

      _processLocationData(_cachedLocations!, currentPosition);

    } catch (e) {
      print('最寄り位置検索エラー: $e');
      setState(() {
        _nearestLocationStatus = "検索エラー: $e";
        _nearestLocations = [];
        _nearestImageUrls = [];
        _showImageSlider = false;
      });
    }
  }

  void _processLocationData(List<Map<String, dynamic>> cachedData, Position currentPosition) {
    List<Map<String, dynamic>> locationDistances = [];

    for (var item in cachedData) {
      try {
        Map<String, dynamic> data = item['data'];

        double? latitude;
        double? longitude;

        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          latitude = (data['latitude'] as num?)?.toDouble();
          longitude = (data['longitude'] as num?)?.toDouble();
        } else if (data.containsKey('point')) {
          GeoPoint? geoPoint = data['point'] as GeoPoint?;
          if (geoPoint != null) {
            latitude = geoPoint.latitude;
            longitude = geoPoint.longitude;
          }
        }

        if (latitude != null && longitude != null) {
          double distance = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            latitude,
            longitude,
          );

          locationDistances.add({
            'id': item['id'],
            'distance': distance,
            'latitude': latitude,
            'longitude': longitude,
            'data': data,
          });
        }
      } catch (e) {
        print('ドキュメント処理エラー (${item['id']}): $e');
      }
    }

    locationDistances.sort((a, b) => a['distance'].compareTo(b['distance']));
    List<Map<String, dynamic>> nearest3 = locationDistances.take(3).toList();

    setState(() {
      _nearestLocations = nearest3;
      _nearestImageUrls = nearest3
          .map((location) {
        var data = location['data'] as Map<String, dynamic>;
        return data['imageUrl'] as String? ?? '';
      })
          .where((url) => url.isNotEmpty)
          .toList();

      if (nearest3.isNotEmpty) {
        _nearestLocationStatus = "最寄り位置を発見（${nearest3.length}箇所）";
        _showImageSlider = _nearestImageUrls.isNotEmpty;
      } else {
        _nearestLocationStatus = "有効な位置データが見つかりません";
        _showImageSlider = false;
      }
    });

    _preloadImages();
  }

  void _preloadImages() {
    for (String imageUrl in _nearestImageUrls) {
      if (!_preloadedImages.contains(imageUrl)) {
        precacheImage(NetworkImage(imageUrl), context).then((_) {
          _preloadedImages.add(imageUrl);
        }).catchError((error) {
          print('画像プリロードエラー: $error');
        });
      }
    }
  }

  void _onModeChanged(String mode) {
    setState(() {
      _selectedMode = mode;
      _hideFocus();
    });
  }

  void _showDraggableImageWithUrl(String imageUrl) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final sliderImageWidth = screenWidth * 0.85;
    final sliderImageHeight = sliderImageWidth * (4 / 6);

    setState(() {
      _showDraggableImage = true;
      _currentDraggableImageUrl = imageUrl;
      _showImageSlider = false;
      _draggableImageScale = 1.0;
      _isScaleMode = false;

      _draggableImageWidth = sliderImageWidth * 0.7;
      _draggableImageHeight = sliderImageHeight * 0.7;

      _draggableImageX = (screenSize.width - _draggableImageWidth) / 2;
      _draggableImageY = (screenSize.height - _draggableImageHeight) / 2;
    });
  }

  void _hideDraggableImage() {
    setState(() {
      _showDraggableImage = false;
      _currentDraggableImageUrl = '';
      _draggableImageScale = 1.0;
      _isScaleMode = false;
      _draggableImageWidth = 200.0;
      _draggableImageHeight = 200.0;
      _showImageSlider = _nearestImageUrls.isNotEmpty;
    });
    _longPressTimer?.cancel();
  }

  void _startScaleMode() {
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isScaleMode = true;
        });
      }
    });
  }

  void _endScaleMode() {
    _longPressTimer?.cancel();
    setState(() {
      _isScaleMode = false;
    });
  }

  void _updateDraggableImageTransform(ScaleUpdateDetails details) {
    if (!_showDraggableImage) return;

    final screenSize = MediaQuery.of(context).size;

    setState(() {
      if (_isScaleMode && details.scale != 1.0) {
        _draggableImageScale = (_draggableImageScale * details.scale)
            .clamp(0.5, 3.0);
      }

      if (!_isScaleMode) {
        _draggableImageX += details.focalPointDelta.dx;
        _draggableImageY += details.focalPointDelta.dy;
      }

      final actualImageWidth = _draggableImageWidth * _draggableImageScale;
      final actualImageHeight = _draggableImageHeight * _draggableImageScale;

      _draggableImageX = _draggableImageX
          .clamp(0.0, screenSize.width - actualImageWidth);
      _draggableImageY = _draggableImageY
          .clamp(0.0, screenSize.height - actualImageHeight);
    });
  }

  void _startFocusTimer() {
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(seconds: 3), () {
      _hideFocus();
    });
  }

  void _hideFocus() {
    _focusTimer?.cancel();
    setState(() {
      _isFocusVisible = false;
      _isExposureVisible = false;
    });
  }

  // UI構築メソッド（既存のものをそのまま使用）
  Widget _buildTopControls() {
    return SafeArea(
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: _toggleFlash,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const InternalGalleryScreen(),
                  ),
                );
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const Spacer(),
            if (_showDraggableImage)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(_draggableImageScale * 100).toInt()}%${_isScaleMode ? ' (スケールモード)' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _hideDraggableImage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSlider() {
    if (!_showImageSlider || _nearestImageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final imageWidth = screenWidth * 0.85;
    final imageHeight = imageWidth * (4 / 6);

    return Positioned(
      top: 115,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: imageWidth,
          height: imageHeight + 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                width: imageWidth,
                height: imageHeight,
                child: PageView.builder(
                  controller: _imagePageController,
                  itemCount: _nearestImageUrls.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.all(8),
                      child: GestureDetector(
                        onTap: () {
                          _showDraggableImageWithUrl(_nearestImageUrls[index]);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _nearestImageUrls[index],
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            cacheWidth: (imageWidth * 2).toInt(),
                            cacheHeight: (imageHeight * 2).toInt(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[800],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.cyan,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[800],
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 32,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_nearestImageUrls.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _nearestImageUrls.length,
                          (index) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == 0
                              ? Colors.lime
                              : (index == 1 ? Colors.orange : Colors.pink),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableImage() {
    if (!_showDraggableImage || _currentDraggableImageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final actualImageWidth = _draggableImageWidth * _draggableImageScale;
    final actualImageHeight = _draggableImageHeight * _draggableImageScale;

    return Positioned(
      left: _draggableImageX,
      top: _draggableImageY,
      child: RepaintBoundary(
        child: GestureDetector(
          onScaleUpdate: _updateDraggableImageTransform,
          onScaleStart: (details) {
            setState(() {
              _isDragging = true;
            });
            _startScaleMode();
          },
          onScaleEnd: (details) {
            setState(() {
              _isDragging = false;
            });
            _endScaleMode();
          },
          child: Container(
            width: actualImageWidth,
            height: actualImageHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: _isScaleMode ? Border.all(color: Colors.yellow, width: 3) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isDragging ? 0.5 : 0.3),
                  blurRadius: _isDragging ? 10 : 5,
                  offset: Offset(0, _isDragging ? 5 : 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _currentDraggableImageUrl,
                width: actualImageWidth,
                height: actualImageHeight,
                fit: BoxFit.cover,
                cacheWidth: (actualImageWidth * 2).toInt(),
                cacheHeight: (actualImageHeight * 2).toInt(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.cyan,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized || _textureId == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(
      onTapUp: (TapUpDetails details) {
        if (!_showDraggableImage) {
          _setFocus(details.localPosition);
        }
      },
      onLongPressStart: (LongPressStartDetails details) {
        if (!_showDraggableImage) {
          _setFocus(details.localPosition);
        }
      },
      onPanUpdate: (DragUpdateDetails details) {
        if (_isExposureVisible && !_showDraggableImage) {
          _updateExposure(details.delta.dy);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ネイティブカメラプレビュー
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: Texture(textureId: _textureId!),
                ),
              ),
            ),
          ),
          if (_isFocusVisible && !_showDraggableImage)
            Positioned(
              left: _focusX - _focusSize / 2,
              top: _focusY - _focusSize / 2,
              child: _buildFocusIndicator(),
            ),
          if (_isExposureVisible && !_showDraggableImage)
            Positioned(
              left: _isExposureOnRight
                  ? _focusX + _focusSize / 2 + 20
                  : _focusX - _focusSize / 2 - 50,
              top: _focusY - _exposureBarHeight / 2,
              child: _buildExposureSlider(),
            ),
        ],
      ),
    );
  }

  Widget _buildFocusIndicator() {
    return Container(
      width: _focusSize,
      height: _focusSize,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.yellow, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.crop_free,
        color: Colors.yellow,
        size: 24,
      ),
    );
  }

  Widget _buildExposureSlider() {
    return Container(
      width: 30,
      height: _exposureBarHeight,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            left: -15,
            right: -15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _exposureValue >= 0
                    ? '+${_exposureValue.toStringAsFixed(1)}'
                    : _exposureValue.toStringAsFixed(1),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Positioned(
            top: _exposureSliderY - 8,
            left: 7,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.yellow,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: _exposureBarHeight / 2 - 1,
            left: 5,
            right: 5,
            child: Container(
              height: 2,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      height: 35,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _cameraModes.map((mode) {
          final isSelected = mode == _selectedMode;
          return GestureDetector(
            onTap: () => _onModeChanged(mode),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    mode,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.yellow
                          : Colors.white.withOpacity(0.7),
                      fontSize: isSelected ? 17 : 15,
                      fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (isSelected)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.yellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 50),
          GestureDetector(
            onTap: () {
              if (_selectedMode == 'ビデオ') {
                _isRecording ? _stopVideoRecording() : _startVideoRecording();
              } else {
                _captureCompositePhoto();
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _selectedMode == 'ビデオ' && _isRecording ? 28 : 64,
                  height: _selectedMode == 'ビデオ' && _isRecording ? 28 : 64,
                  decoration: BoxDecoration(
                    color: _selectedMode == 'ビデオ' && _isRecording
                        ? Colors.red
                        : Colors.white,
                    shape: _selectedMode == 'ビデオ' && _isRecording
                        ? BoxShape.rectangle
                        : BoxShape.circle,
                    borderRadius: _selectedMode == 'ビデオ' && _isRecording
                        ? BorderRadius.circular(6)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _switchCamera,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flip_camera_ios,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // ネイティブカメラを停止
    _cameraChannel.invokeMethod('dispose');

    _focusTimer?.cancel();
    _longPressTimer?.cancel();
    _positionStream?.cancel();
    _locationDebouncer?.cancel();
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildDraggableImage(),
          _buildImageSlider(),
          _buildTopControls(),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black54,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  _buildModeSelector(),
                  const SizedBox(height: 15),
                  _buildBottomControls(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// InternalGalleryScreenは既存のものをそのまま使用
class InternalGalleryScreen extends StatefulWidget {
  const InternalGalleryScreen({Key? key}) : super(key: key);

  @override
  State<InternalGalleryScreen> createState() => _InternalGalleryScreenState();
}

class _InternalGalleryScreenState extends State<InternalGalleryScreen> {
  List<File> _savedImages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedImages();
  }

  Future<void> _loadSavedImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);

      if (await dir.exists()) {
        final files = await dir.list(recursive: true).toList();
        final imageFiles = files
            .where((file) => file is File)
            .cast<File>()
            .where((file) =>
        file.path.toLowerCase().endsWith('.jpg') ||
            file.path.toLowerCase().endsWith('.jpeg') ||
            file.path.toLowerCase().endsWith('.png'))
            .toList();

        imageFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        setState(() {
          _savedImages = imageFiles;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('画像読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteImage(File imageFile) async {
    try {
      await imageFile.delete();
      _loadSavedImages();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像を削除しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    }
  }

  Future<void> _shareImage(File imageFile) async {
    try {
      await Clipboard.setData(ClipboardData(text: imageFile.path));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ファイルパスをクリップボードにコピーしました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('共有に失敗しました: $e')),
      );
    }
  }

  Future<void> _moveToPhotoLibrary(File imageFile) async {
    try {
      final result = await ImageGallerySaver.saveFile(imageFile.path);
      if (result['isSuccess'] == true) {
        await imageFile.delete();
        _loadSavedImages();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フォトライブラリに移動しました')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移動に失敗しました: ${result['errorMessage'] ?? '不明なエラー'}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移動に失敗しました: $e')),
      );
    }
  }

  void _showImageDialog(File imageFile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: InteractiveViewer(
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _moveToPhotoLibrary(imageFile),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('フォトライブラリに移動'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _shareImage(imageFile),
                    icon: const Icon(Icons.share),
                    label: const Text('共有'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showDeleteConfirmation(imageFile);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('削除'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('閉じる'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(File imageFile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('画像を削除'),
          content: const Text('この画像を削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteImage(imageFile);
              },
              child: const Text('削除'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }

  String _getImageDate(File imageFile) {
    final date = imageFile.lastModifiedSync();
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('保存された写真'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadSavedImages,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.white),
      )
          : _savedImages.isEmpty
          ? const Center(
        child: Text(
          'まだ写真が保存されていません',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '保存された写真: ${_savedImages.length}枚',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _savedImages.length,
              itemBuilder: (context, index) {
                final imageFile = _savedImages[index];
                return GestureDetector(
                  onTap: () => _showImageDialog(imageFile),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            imageFile,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                ),
                              ),
                              child: Text(
                                _getImageDate(imageFile),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
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
        ],
      ),
    );
  }
}