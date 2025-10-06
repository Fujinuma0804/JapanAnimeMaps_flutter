import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class CameraPostsPage extends StatefulWidget {
  final List<CameraDescription>? cameras;

  const CameraPostsPage({Key? key, this.cameras}) : super(key: key);

  @override
  State<CameraPostsPage> createState() => _CameraPostsPageState();
}

class _CameraPostsPageState extends State<CameraPostsPage>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRearCameraSelected = true;
  final ImagePicker _imagePicker = ImagePicker();
  String? _capturedImagePath;
  List<CameraDescription> _cameras = [];

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCameraList();
    _initializeAnimations();
  }

  void _initializeCameraList() async {
    if (widget.cameras != null) {
      _cameras = widget.cameras!;
    } else {
      _cameras = await availableCameras();
    }
    _initializeCamera();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();
  }

  void _initializeCamera() async {
    if (_cameras.isEmpty) return;

    final camera = _cameras[_isRearCameraSelected ? 0 : (_cameras.length > 1 ? 1 : 0)];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _toggleCamera() async {
    if (_cameras.length < 2) return; // カメラが1つしかない場合は何もしない

    setState(() {
      _isRearCameraSelected = !_isRearCameraSelected;
      _isCameraInitialized = false;
    });

    await _cameraController?.dispose();
    _initializeCamera();
  }

  Future<void> _takePicture() async {
    if (!_cameraController!.value.isInitialized) return;

    try {
      final image = await _cameraController!.takePicture();
      setState(() {
        _capturedImagePath = image.path;
      });

      // シャッター音効果のアニメーション
      _scaleController.reset();
      _scaleController.forward();

    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _capturedImagePath = image.path;
      });
    }
  }

  void _onNextPressed() {
    if (_capturedImagePath != null) {
      // 次の画面への遷移処理をここに実装
      print('Next button pressed with image: $_capturedImagePath');
      // Navigator.push(context, MaterialPageRoute(builder: (context) => NextPage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('写真を撮影するか、ギャラリーから選択してください'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Stack(
              children: [
                // カメラプレビュー
                if (_isCameraInitialized)
                  Positioned.fill(
                    child: AspectRatio(
                      aspectRatio: _cameraController!.value.aspectRatio,
                      child: CameraPreview(_cameraController!),
                    ),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),

                // 上部のグラデーションオーバーレイ
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x80000000),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // 下部のグラデーションオーバーレイ
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 200,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0x80000000),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // 上部のコントロール
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 戻るボタン
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      // カメラ切り替えボタン
                      if (_cameras.length > 1)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.flip_camera_ios,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: _toggleCamera,
                          ),
                        ),
                    ],
                  ),
                ),

                // 下部のコントロール
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 撮影ボタンとギャラリーボタン
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // 空のスペース（バランス調整用）
                            const SizedBox(width: 60),

                            // 撮影ボタン
                            AnimatedBuilder(
                              animation: _scaleAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _scaleAnimation.value,
                                  child: GestureDetector(
                                    onTap: _takePicture,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.black,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // ギャラリーボタン
                            GestureDetector(
                              onTap: _pickImageFromGallery,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: Colors.white.withOpacity(0.1),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.photo_library,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 次へボタン
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            gradient: LinearGradient(
                              colors: _capturedImagePath != null
                                  ? [
                                const Color(0xFF6C5CE7),
                                const Color(0xFF74B9FF),
                              ]
                                  : [
                                Colors.grey.withOpacity(0.3),
                                Colors.grey.withOpacity(0.5),
                              ],
                            ),
                            boxShadow: _capturedImagePath != null
                                ? [
                              BoxShadow(
                                color: const Color(0xFF6C5CE7).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ]
                                : null,
                          ),
                          child: ElevatedButton(
                            onPressed: _onNextPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '次へ',
                                  style: TextStyle(
                                    color: _capturedImagePath != null
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.6),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: _capturedImagePath != null
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.6),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 撮影した画像のプレビュー（右上）
                if (_capturedImagePath != null)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 80,
                    right: 20,
                    child: Container(
                      width: 60,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_capturedImagePath!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}