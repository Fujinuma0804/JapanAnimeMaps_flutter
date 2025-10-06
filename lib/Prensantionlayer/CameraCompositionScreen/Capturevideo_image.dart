import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// Sacred Site Data Model
class SacredSite {
  final String id;
  final String imageUrl;
  final String locationID;
  final double latitude;
  final double longitude;
  final int point;
  final String sourceLink;
  final String sourceTitle;
  final String subMedia;

  SacredSite({
    required this.id,
    required this.imageUrl,
    required this.locationID,
    required this.latitude,
    required this.longitude,
    required this.point,
    required this.sourceLink,
    required this.sourceTitle,
    required this.subMedia,
  });
}

// camera_capture_screen.dart

class CameraCaptureScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraCaptureScreen({super.key, required this.camera});

  @override
  _CameraCaptureScreenState createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  bool _isFrontCamera = false;
  bool _isRecording = false;
  bool _isCameraReady = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  CaptureMode _captureMode = CaptureMode.photo;

  @override
  void initState() {
    super.initState();
    _initializeCameraController();
  }

  Future<void> _initializeCameraController() async {
    final controller = await _initializeCamera();
    if (mounted) {
      setState(() {
        _controller = controller;
        _isCameraReady = controller?.value.isInitialized ?? false;
      });
    }
  }

  // Define a future that will resolve to the controller.
  Future<CameraController?> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('No cameras available');
        return null;
      }

      final camera =
          _isFrontCamera && cameras.length > 1 ? cameras[1] : cameras.first;

      final controller = CameraController(
        camera,
        _captureMode == CaptureMode.photo
            ? ResolutionPreset.medium
            : ResolutionPreset.medium,
        enableAudio: _captureMode ==
            CaptureMode.video, // Enable audio only for video recording
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      // Listen to camera state changes
      controller.addListener(() {
        if (mounted) {
          setState(() {
            _isCameraReady = controller.value.isInitialized;
          });
        }
      });

      return controller;
    } catch (e) {
      print('Error initializing camera: $e');
      return null;
    }
  }

  Future<void> _switchCamera() async {
    if (_controller == null) return;

    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isCameraReady = false;
    });

    await _controller?.dispose();
    _controller = null;

    // Re-initialize with the new camera
    final newController = await _initializeCamera();
    if (mounted) {
      setState(() {
        _controller = newController;
        _isCameraReady = newController?.value.isInitialized ?? false;
      });
    }
  }

  Future<void> _switchCaptureMode() async {
    if (_controller == null) return;

    setState(() {
      _captureMode = _captureMode == CaptureMode.photo
          ? CaptureMode.video
          : CaptureMode.photo;
      _isCameraReady = false;
      _isRecording = false;
      _recordingSeconds = 0;
    });

    _recordingTimer?.cancel();
    await _controller?.dispose();
    _controller = null;

    // Re-initialize with the new mode
    final newController = await _initializeCamera();
    if (mounted) {
      setState(() {
        _controller = newController;
        _isCameraReady = newController?.value.isInitialized ?? false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print("Error: Camera controller is not ready.");
      _showErrorSnackBar('Camera not ready. Please wait for initialization.');
      return;
    }

    try {
      setState(() {
        _isCameraReady = false; // Disable capture during processing
      });

      final XFile image = await _controller!.takePicture();
      if (!mounted) return;

      // Return the captured image
      Navigator.pop(
          context,
          CaptureResult(
            file: File(image.path),
            type: CaptureType.photo,
            duration: null,
          ));
    } catch (e) {
      print('Error taking picture: $e');
      _showErrorSnackBar('Failed to capture photo: ${e.toString()}');
      if (mounted) {
        setState(() {
          _isCameraReady = _controller?.value.isInitialized ?? false;
        });
      }
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print("Error: Camera controller is not ready.");
      _showErrorSnackBar('Camera not ready. Please wait for initialization.');
      return;
    }

    if (_controller!.value.isRecordingVideo) {
      // A recording has already started, do nothing.
      return;
    }

    try {
      await _controller!.startVideoRecording();
      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordingSeconds = 0;
        });

        // Start recording timer
        _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingSeconds = timer.tick;
            });
          }
        });
      }
    } catch (e) {
      print('Error starting video recording: $e');
      _showErrorSnackBar('Failed to start recording: ${e.toString()}');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      return;
    }

    try {
      final XFile videoFile = await _controller!.stopVideoRecording();
      _recordingTimer?.cancel();

      if (mounted) {
        setState(() {
          _isRecording = false;
        });

        // Return the recorded video
        Navigator.pop(
            context,
            CaptureResult(
              file: File(videoFile.path),
              type: CaptureType.video,
              duration: Duration(seconds: _recordingSeconds),
            ));
      }
    } catch (e) {
      print('Error stopping video recording: $e');
      _showErrorSnackBar('Failed to stop recording: ${e.toString()}');
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_captureMode == CaptureMode.photo ? '写真を撮る' : 'ビデオを録画する',
            style: TextStyle(color: Colors.white)),
        actions: [
          // Mode switcher
          IconButton(
            icon: Icon(
              _captureMode == CaptureMode.photo
                  ? Icons.videocam
                  : Icons.photo_camera,
              color: Colors.white,
            ),
            onPressed: _switchCaptureMode,
          ),
          // Camera switcher
          IconButton(
            icon: Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: _controller == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  SizedBox(height: 16),
                  Text('カメラを初期化しています...',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            )
          : _isCameraReady
              ? Stack(
                  children: [
                    CameraPreview(_controller!),

                    // Recording timer overlay for video mode
                    if (_captureMode == CaptureMode.video && _isRecording)
                      Positioned(
                        top: 40,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'REC ${_formatDuration(_recordingSeconds)}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Mode indicator
                    Positioned(
                      top: 40,
                      left: 16,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _captureMode == CaptureMode.photo
                                  ? Icons.photo_camera
                                  : Icons.videocam,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              _captureMode == CaptureMode.photo ? '写真' : 'ビデオ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.white, size: 64),
                      SizedBox(height: 16),
                      Text('Camera not ready',
                          style: TextStyle(color: Colors.white)),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final newController = await _initializeCamera();
                          if (mounted) {
                            setState(() {
                              _controller = newController;
                              _isCameraReady =
                                  newController?.value.isInitialized ?? false;
                            });
                          }
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: _buildCaptureButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCaptureButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_captureMode == CaptureMode.video && _isRecording)
          Container(
            margin: EdgeInsets.only(bottom: 20),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Recording: ${_formatDuration(_recordingSeconds)}',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        FloatingActionButton(
          backgroundColor: _isRecording ? Colors.red : Colors.white,
          onPressed: () {
            if (_captureMode == CaptureMode.photo) {
              _capturePhoto();
            } else {
              if (_isRecording) {
                _stopVideoRecording();
              } else {
                _startVideoRecording();
              }
            }
          },
          child: Icon(
            _captureMode == CaptureMode.photo
                ? Icons.camera_alt
                : _isRecording
                    ? Icons.stop
                    : Icons.videocam,
            color: _isRecording ? Colors.white : Colors.black,
            size: _captureMode == CaptureMode.photo ? 24 : 28,
          ),
        ),
      ],
    );
  }
}

// Enums for capture modes and types
enum CaptureMode { photo, video }

enum CaptureType { photo, video }

enum MediaType { none, image, video }

// Result class to handle both photo and video results
class CaptureResult {
  final File file;
  final CaptureType type;
  final Duration? duration;

  CaptureResult({
    required this.file,
    required this.type,
    this.duration,
  });
}

// Video Player Widget for video preview
class VideoPlayerWidget extends StatefulWidget {
  final File videoFile;
  final bool isPlaying;

  const VideoPlayerWidget({
    Key? key,
    required this.videoFile,
    this.isPlaying = true,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (widget.isPlaying) {
          _controller!.play();
        }
      }
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}
