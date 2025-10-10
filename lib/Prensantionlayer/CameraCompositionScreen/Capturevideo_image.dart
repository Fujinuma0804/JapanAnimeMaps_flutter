import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:parts/Prensantionlayer/CameraCompositionScreen/sacred_site_model.dart';
import 'package:parts/Prensantionlayer/CameraCompositionScreen/ScaredSitebottomsheet.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:photo_manager/photo_manager.dart';

// Enums for capture modes and types
enum CaptureMode { photo, video }

enum CaptureType { photo, video }

class CameraCaptureScreen extends StatefulWidget {
  final CameraDescription camera;
  final SacredSite? initialSacredSite;
  final Uint8List? sacredSiteImageBytes;
  final Function(SacredSite)? onSacredSiteSelected;

  const CameraCaptureScreen({
    super.key,
    required this.camera,
    this.initialSacredSite,
    this.sacredSiteImageBytes,
    this.onSacredSiteSelected,
  });

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

  // Sacred site overlay properties
  SacredSite? _selectedSacredSite;
  Uint8List? _sacredSiteImageBytes;
  bool _isLoadingOverlay = false;

  // Composition controls
  double _opacity = 0.7;
  double _scale = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;
  bool _showControls = true;
  bool _showOverlay = true;

  // Performance optimization
  DateTime _lastScaleUpdate = DateTime.now();
  static const Duration _scaleUpdateThrottle = Duration(milliseconds: 16);

  // Processing states
  bool _isProcessing = false;
  bool _isSaving = false;

  // Preview states
  bool _showPreview = false;
  File? _previewFile;
  Uint8List? _previewImageBytes;
  CaptureType? _previewType;
  VideoPlayerController? _previewVideoController;

  @override
  void initState() {
    super.initState();
    _initializeCameraController();

    // Use provided sacred site data or load initial sacred site
    _initializeSacredSiteData();
  }

  void _initializeSacredSiteData() {
    if (widget.sacredSiteImageBytes != null) {
      // If image bytes are provided directly, use them
      setState(() {
        _sacredSiteImageBytes = widget.sacredSiteImageBytes;
        _selectedSacredSite = widget.initialSacredSite;
        _showOverlay = true;
      });
    } else if (widget.initialSacredSite != null) {
      // If only sacred site is provided, load the image
      _selectedSacredSite = widget.initialSacredSite;
      _loadSacredSiteImage(widget.initialSacredSite!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recordingTimer?.cancel();
    _previewVideoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCameraController() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showErrorSnackBar('No cameras available');
        return;
      }

      final camera =
          _isFrontCamera && cameras.length > 1 ? cameras[1] : cameras.first;

      final controller = CameraController(
        camera,
        _captureMode == CaptureMode.photo
            ? ResolutionPreset.medium
            : ResolutionPreset.medium,
        enableAudio: _captureMode == CaptureMode.video,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (mounted) {
        setState(() {
          _controller = controller;
          _isCameraReady = controller.value.isInitialized;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to initialize camera');
      }
    }
  }

  Future<void> _selectSacredSite() async {
    // Add a small delay to ensure navigator is not locked
    await Future.delayed(Duration(milliseconds: 100));

    if (!mounted) return;

    try {
      final selectedSite = await showModalBottomSheet<SacredSite>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SacredSiteBottomSheet(
          selectedSacredSite: _selectedSacredSite,
        ),
      );

      if (selectedSite != null && mounted) {
        print('Selected sacred site: ${selectedSite.sourceTitle}');
        await _loadSacredSiteImage(selectedSite);
        widget.onSacredSiteSelected?.call(selectedSite);
      }
    } catch (e) {
      print('Error showing sacred site bottom sheet: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to open sacred site selector');
      }
    }
  }

// IMPROVED: Sacred site image loading with better error handling and debugging
  Future<void> _loadSacredSiteImage(SacredSite site) async {
    if (!mounted) return;

    setState(() {
      _isLoadingOverlay = true;
    });

    try {
      print('Loading sacred site image from: ${site.imageUrl}');

      final response = await http.get(Uri.parse(site.imageUrl));

      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;

        // Verify the image bytes are valid
        if (imageBytes.isNotEmpty) {
          // Test if the image can be decoded
          try {
            await ui.instantiateImageCodec(imageBytes);

            if (mounted) {
              setState(() {
                _sacredSiteImageBytes = imageBytes;
                _selectedSacredSite = site;
                _isLoadingOverlay = false;
                _showOverlay = true;
              });
            }
            print(
                'Sacred site image loaded successfully - ${imageBytes.length} bytes');
            _showSuccessSnackBar(
                'Sacred site "${site.sourceTitle}" loaded successfully!');
          } catch (decodeError) {
            print('Error decoding image: $decodeError');
            throw Exception('Image format not supported');
          }
        } else {
          throw Exception('Empty image data received');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error loading sacred site image: $e');
      if (mounted) {
        setState(() {
          _isLoadingOverlay = false;
        });
        _showErrorSnackBar('Failed to load sacred site image: ${e.toString()}');
      }
    }
  }
  // IMPROVED: Sacred site image loading with better error handling

  // Rest of your existing methods remain the same...
  Future<void> _switchCamera() async {
    if (_controller == null || !mounted) return;

    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isCameraReady = false;
    });

    await _controller?.dispose();
    _controller = null;

    await _initializeCameraController();
  }

  Future<void> _switchCaptureMode() async {
    if (_controller == null || !mounted) return;

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

    await _initializeCameraController();
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || !mounted) {
      _showErrorSnackBar('Camera not ready. Please wait for initialization.');
      return;
    }

    if (_isProcessing) {
      _showErrorSnackBar('Please wait, processing previous capture...');
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      final XFile image = await _controller!.takePicture();

      if (!mounted) return;

      // Handle image rotation for front camera
      File processedImageFile = File(image.path);
      if (_isFrontCamera) {
        processedImageFile = await _rotateImageForFrontCamera(File(image.path));
      }

      // If we have an overlay, create the final composition
      File finalImageFile;
      Uint8List? finalImageBytes;

      if (_showOverlay && _sacredSiteImageBytes != null) {
        finalImageFile = await _createComposedImage(processedImageFile);
        finalImageBytes = await finalImageFile.readAsBytes();
      } else {
        finalImageFile = processedImageFile;
        finalImageBytes = await finalImageFile.readAsBytes();
      }

      // Show preview
      _showMediaPreview(finalImageFile, finalImageBytes, CaptureType.photo);
    } catch (e) {
      print('Error taking picture: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to capture photo: ${e.toString()}');
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<File> _rotateImageForFrontCamera(File originalImage) async {
    try {
      final originalBytes = await originalImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(originalBytes);
      final frame = await codec.getNextFrame();
      final originalUiImage = frame.image;

      // Create a new image with the same dimensions but flipped horizontally for front camera
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Flip horizontally for front camera
      canvas.translate(originalUiImage.width.toDouble(), 0);
      canvas.scale(-1.0, 1.0);

      canvas.drawImageRect(
        originalUiImage,
        ui.Rect.fromLTWH(0, 0, originalUiImage.width.toDouble(),
            originalUiImage.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, originalUiImage.width.toDouble(),
            originalUiImage.height.toDouble()),
        ui.Paint()..isAntiAlias = true,
      );

      final picture = recorder.endRecording();
      final rotatedImage =
          await picture.toImage(originalUiImage.width, originalUiImage.height);
      final byteData =
          await rotatedImage.toByteData(format: ui.ImageByteFormat.png);

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.png';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(byteData!.buffer.asUint8List());

      // Clean up
      originalUiImage.dispose();
      rotatedImage.dispose();

      return outputFile;
    } catch (e) {
      print('Error rotating image: $e');
      return originalImage; // Fallback to original image
    }
  }

  Future<File> _createComposedImage(File originalImage) async {
    try {
      // Read original image
      final originalBytes = await originalImage.readAsBytes();
      final codec = await ui.instantiateImageCodec(originalBytes);
      final frame = await codec.getNextFrame();
      final originalUiImage = frame.image;

      // Create canvas with original image dimensions
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Draw original image as background
      canvas.drawImageRect(
        originalUiImage,
        ui.Rect.fromLTWH(0, 0, originalUiImage.width.toDouble(),
            originalUiImage.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, originalUiImage.width.toDouble(),
            originalUiImage.height.toDouble()),
        ui.Paint()..isAntiAlias = true,
      );

      // Draw overlay image if available and visible
      if (_showOverlay && _sacredSiteImageBytes != null) {
        final overlayCodec =
            await ui.instantiateImageCodec(_sacredSiteImageBytes!);
        final overlayFrame = await overlayCodec.getNextFrame();
        final overlayImage = overlayFrame.image;

        canvas.save();
        canvas.translate(originalUiImage.width / 2, originalUiImage.height / 2);
        canvas.translate(_offsetX, _offsetY);
        canvas.scale(_scale);

        final overlayPaint = ui.Paint()
          ..isAntiAlias = true
          ..filterQuality = ui.FilterQuality.high
          ..color = ui.Color.fromRGBO(255, 255, 255, _opacity);

        final double scaledWidth = overlayImage.width.toDouble() * _scale;
        final double scaledHeight = overlayImage.height.toDouble() * _scale;

        canvas.drawImageRect(
          overlayImage,
          ui.Rect.fromLTWH(0, 0, overlayImage.width.toDouble(),
              overlayImage.height.toDouble()),
          ui.Rect.fromCenter(
              center: ui.Offset.zero, width: scaledWidth, height: scaledHeight),
          overlayPaint,
        );

        canvas.restore();
        overlayImage.dispose();
      }

      final picture = recorder.endRecording();
      final composedImage =
          await picture.toImage(originalUiImage.width, originalUiImage.height);
      final byteData =
          await composedImage.toByteData(format: ui.ImageByteFormat.png);

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/composed_${DateTime.now().millisecondsSinceEpoch}.png';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(byteData!.buffer.asUint8List());

      // Clean up
      originalUiImage.dispose();
      composedImage.dispose();

      return outputFile;
    } catch (e) {
      print('Error creating composed image: $e');
      return originalImage; // Fallback to original image
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || !mounted) {
      _showErrorSnackBar('Camera not ready. Please wait for initialization.');
      return;
    }

    if (_controller!.value.isRecordingVideo) {
      return;
    }

    try {
      await _controller!.startVideoRecording();
      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordingSeconds = 0;
        });

        _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingSeconds = timer.tick;
            });
          } else {
            timer.cancel();
          }
        });
      }
    } catch (e) {
      print('Error starting video recording: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to start recording: ${e.toString()}');
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null ||
        !_controller!.value.isRecordingVideo ||
        !mounted) {
      return;
    }

    if (_isProcessing) {
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      final XFile videoFile = await _controller!.stopVideoRecording();
      _recordingTimer?.cancel();

      if (mounted) {
        setState(() {
          _isRecording = false;
        });

        // Process video with overlay if needed
        if (_showOverlay && _sacredSiteImageBytes != null) {
          await _processVideoWithOverlay(File(videoFile.path));
        } else {
          _showMediaPreview(File(videoFile.path), null, CaptureType.video);
        }
      }
    } catch (e) {
      print('Error stopping video recording: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to stop recording: ${e.toString()}');
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processVideoWithOverlay(File originalVideo) async {
    try {
      setState(() {
        _isProcessing = true;
      });

      // Save sacred site image to temporary file
      final tempDir = await getTemporaryDirectory();
      final overlayImagePath =
          '${tempDir.path}/overlay_${DateTime.now().millisecondsSinceEpoch}.png';
      final overlayFile = File(overlayImagePath);
      await overlayFile.writeAsBytes(_sacredSiteImageBytes!);

      // Get video dimensions
      final videoInfo = await _getVideoDimensions(originalVideo.path);
      final videoWidth = videoInfo['width'] ?? 1920;
      final videoHeight = videoInfo['height'] ?? 1080;

      // Create output path
      final outputPath =
          '${tempDir.path}/sacred_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Build FFmpeg command for overlay - FIXED VERSION
      final command = _buildOverlayCommand(
        videoPath: originalVideo.path,
        imagePath: overlayImagePath,
        outputPath: outputPath,
        offsetX: _offsetX,
        offsetY: _offsetY,
        scale: _scale,
        opacity: _opacity,
        videoWidth: videoWidth,
        videoHeight: videoHeight,
      );

      print('FFmpeg Command: $command');

      // Execute FFmpeg command with timeout and better error handling
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final logs = await session.getAllLogs();

      // Print logs for debugging
      for (final log in logs) {
        print('FFmpeg Log: ${log.getMessage()}');
      }

      // Clean up temporary overlay file
      await overlayFile.delete();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final fileSize = await outputFile.length();
          print('Output file created: $outputPath, size: $fileSize bytes');

          if (fileSize > 0) {
            _showMediaPreview(outputFile, null, CaptureType.video);
          } else {
            throw Exception('Output file is empty');
          }
        } else {
          throw Exception('Output file was not created');
        }
      } else {
        final failureLog = await session.getFailStackTrace();
        print('FFmpeg processing failed with return code: $returnCode');
        print('Failure stack trace: $failureLog');
        throw Exception('FFmpeg processing failed with code: $returnCode');
      }
    } catch (e) {
      print('Error processing video with overlay: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to process video: ${e.toString()}');
      }
      // Fallback to original video without overlay
      _showMediaPreview(originalVideo, null, CaptureType.video);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

// FIXED: Improved FFmpeg command with better overlay handling
  String _buildOverlayCommand({
    required String videoPath,
    required String imagePath,
    required String outputPath,
    required double offsetX,
    required double offsetY,
    required double scale,
    required double opacity,
    required int videoWidth,
    required int videoHeight,
  }) {
    try {
      // Calculate overlay dimensions based on scale
      final baseOverlayWidth =
          (videoWidth * 0.3).toInt(); // Base size relative to video
      final baseOverlayHeight = (videoHeight * 0.3).toInt();

      final overlayWidth =
          (baseOverlayWidth * scale).clamp(50, videoWidth - 100).toInt();
      final overlayHeight =
          (baseOverlayHeight * scale).clamp(50, videoHeight - 100).toInt();

      // Calculate position - convert offsets from screen coordinates to video coordinates
      // The offsets from gesture are in screen pixels, we need to convert to video coordinates
      final scaleFactorX = videoWidth / MediaQuery.of(context).size.width;
      final scaleFactorY = videoHeight / MediaQuery.of(context).size.height;

      final scaledOffsetX = (offsetX * scaleFactorX).toInt();
      final scaledOffsetY = (offsetY * scaleFactorY).toInt();

      // Calculate center position with offsets
      final centerX = (videoWidth / 2).toInt();
      final centerY = (videoHeight / 2).toInt();

      final overlayX = (centerX + scaledOffsetX - (overlayWidth / 2)).toInt();
      final overlayY = (centerY + scaledOffsetY - (overlayHeight / 2)).toInt();

      // Ensure coordinates are within bounds
      final safeOverlayX = overlayX.clamp(0, videoWidth - overlayWidth);
      final safeOverlayY = overlayY.clamp(0, videoHeight - overlayHeight);

      // Build the FFmpeg command with proper escaping and error handling
      return '''
      -i "$videoPath" 
      -i "$imagePath" 
      -filter_complex "
        [1:v]scale=$overlayWidth:$overlayHeight[scaled_overlay];
        [scaled_overlay]format=rgba,colorchannelmixer=aa=${opacity.toStringAsFixed(2)}[transparent_overlay];
        [0:v][transparent_overlay]overlay=x=$safeOverlayX:y=$safeOverlayY:enable='between(t,0,1e+6)'[v]
      " 
      -map "[v]" 
      -map "0:a?" 
      -c:v libx264 
      -preset fast 
      -crf 23 
      -c:a aac 
      -b:a 128k 
      -movflags +faststart 
      -pix_fmt yuv420p 
      -y 
      "$outputPath"
    '''
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(' +'), ' ')
          .trim();
    } catch (e) {
      print('Error building FFmpeg command: $e');
      // Fallback to simple command without overlay if there's an error
      return '''
      -i "$videoPath" 
      -c:v libx264 
      -preset fast 
      -crf 23 
      -c:a aac 
      -b:a 128k 
      -movflags +faststart 
      -pix_fmt yuv420p 
      -y 
      "$outputPath"
    '''
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(' +'), ' ')
          .trim();
    }
  }

// IMPROVED: Better video dimension detection
  Future<Map<String, int>> _getVideoDimensions(String videoPath) async {
    try {
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      final width = controller.value.size.width.toInt();
      final height = controller.value.size.height.toInt();
      final duration = controller.value.duration;
      await controller.dispose();

      print('Video dimensions: ${width}x${height}, duration: $duration');

      if (width == 0 || height == 0) {
        throw Exception('Invalid video dimensions');
      }

      if (duration.inSeconds == 0) {
        throw Exception('Video has zero duration');
      }

      return {'width': width, 'height': height};
    } catch (e) {
      print('Error getting video dimensions: $e');
      // Return safe default dimensions
      return {'width': 1280, 'height': 720};
    }
  }

// ADDED: Fallback method for video processing without overlay
  Future<void> _processVideoWithoutOverlay(File originalVideo) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/simple_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Simple copy command without overlay
      final command = '''
      -i "$originalVideo.path" 
      -c copy 
      -y 
      "$outputPath"
    '''
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(' +'), ' ')
          .trim();

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          _showMediaPreview(outputFile, null, CaptureType.video);
        } else {
          throw Exception('Output file not created in fallback');
        }
      } else {
        throw Exception('Fallback processing failed');
      }
    } catch (e) {
      print('Error in fallback video processing: $e');
      // Ultimate fallback - use original file
      _showMediaPreview(originalVideo, null, CaptureType.video);
    }
  }

  void _showMediaPreview(File file, Uint8List? imageBytes, CaptureType type) {
    if (!mounted) return;

    if (type == CaptureType.video) {
      _previewVideoController?.dispose();
      _previewVideoController = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _previewFile = file;
              _previewType = type;
              _showPreview = true;
              _isProcessing = false;
            });
            _previewVideoController!.play();
            _previewVideoController!.setLooping(true);
          }
        }).catchError((e) {
          print('Error initializing video preview: $e');
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        });
    } else {
      setState(() {
        _previewFile = file;
        _previewImageBytes = imageBytes;
        _previewType = type;
        _showPreview = true;
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveMedia() async {
    if (_previewFile == null || !mounted) return;

    try {
      setState(() {
        _isSaving = true;
      });

      bool saved = false;

      if (_previewType == CaptureType.photo) {
        saved = await _saveImage(_previewFile!);
      } else {
        saved = await _saveVideo(_previewFile!);
      }

      if (mounted) {
        if (saved) {
          _showSuccessSnackBar('Media saved to gallery successfully!');
          _closePreview();
        } else {
          _showErrorSnackBar('Failed to save media to gallery');
        }
      }
    } catch (e) {
      print('Error saving media: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to save media: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _saveImage(File imageFile) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final AssetEntity? savedAsset = await PhotoManager.editor.saveImage(
        imageBytes,
        title: 'sacred_photo_${DateTime.now().millisecondsSinceEpoch}',
        filename: 'sacred_photo_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      return savedAsset != null;
    } catch (e) {
      print('Error saving image: $e');
      return false;
    }
  }

  Future<bool> _saveVideo(File videoFile) async {
    try {
      // Check if file exists and is readable
      if (!await videoFile.exists()) {
        print('Video file does not exist: ${videoFile.path}');
        return false;
      }

      final fileSize = await videoFile.length();
      if (fileSize == 0) {
        print('Video file is empty: ${videoFile.path}');
        return false;
      }

      print(
          'Attempting to save video: ${videoFile.path}, size: $fileSize bytes');

      // Method 1: Try using PhotoManager
      try {
        final AssetEntity? savedAsset = await PhotoManager.editor.saveVideo(
          videoFile,
          title: 'sacred_video_${DateTime.now().millisecondsSinceEpoch}',
        );

        if (savedAsset != null) {
          print(
              'Video saved successfully with PhotoManager, asset ID: ${savedAsset.id}');

          // Clean up temporary file after successful save
          try {
            await videoFile.delete();
            print('Temporary video file cleaned up');
          } catch (e) {
            print('Warning: Could not delete temporary video file: $e');
          }

          return true;
        }
      } catch (photoManagerError) {
        print('PhotoManager video save failed: $photoManagerError');
      }

      // Method 2: Fallback - Save to app directory
      return await _saveVideoWithFallback(videoFile);
    } catch (e) {
      print('Error saving video: $e');
      return false;
    }
  }

// FALLBACK: Alternative image saving method
  Future<bool> _saveImageWithFallback(File imageFile) async {
    try {
      // Get the app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final savedImagePath =
          '${directory.path}/sacred_photo_${DateTime.now().millisecondsSinceEpoch}.png';

      // Copy the file to app documents directory
      await imageFile.copy(savedImagePath);

      print('Image saved to app directory: $savedImagePath');

      // Show success message with location
      if (mounted) {
        _showSuccessSnackBar('Image saved to app gallery!');
      }

      return true;
    } catch (e) {
      print('Fallback image save also failed: $e');
      return false;
    }
  }

// FALLBACK: Alternative video saving method
  Future<bool> _saveVideoWithFallback(File videoFile) async {
    try {
      // Get the app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final savedVideoPath =
          '${directory.path}/sacred_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Copy the file to app documents directory
      await videoFile.copy(savedVideoPath);

      print('Video saved to app directory: $savedVideoPath');

      // Show success message with location
      if (mounted) {
        _showSuccessSnackBar('Video saved to app gallery!');
      }

      return true;
    } catch (e) {
      print('Fallback video save also failed: $e');
      return false;
    }
  }

// UPDATED: Save media method with better error reporting

// ADDED: Show alternative save options

// ADDED: Save to app directory as fallback
  Future<void> _saveToAppDirectory() async {
    if (_previewFile == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = _previewType == CaptureType.photo
          ? 'sacred_photo_${DateTime.now().millisecondsSinceEpoch}.png'
          : 'sacred_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final savedPath = '${directory.path}/$fileName';
      await _previewFile!.copy(savedPath);

      if (mounted) {
        _showSuccessSnackBar('Saved to app directory!');
        _closePreview();
      }
    } catch (e) {
      print('Error saving to app directory: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to save to app directory: ${e.toString()}');
      }
    }
  }

// ADDED: Check file validity before saving
  Future<bool> _validateFile(File file) async {
    try {
      if (!await file.exists()) {
        print('File does not exist: ${file.path}');
        return false;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        print('File is empty: ${file.path}');
        return false;
      }

      // For images, verify it can be decoded
      if (file.path.toLowerCase().endsWith('.png') ||
          file.path.toLowerCase().endsWith('.jpg') ||
          file.path.toLowerCase().endsWith('.jpeg')) {
        try {
          final bytes = await file.readAsBytes();
          await ui.instantiateImageCodec(bytes);
        } catch (e) {
          print('File is not a valid image: $e');
          return false;
        }
      }

      // For videos, check if it has reasonable size
      if (fileSize < 1024) {
        // Less than 1KB
        print('File too small to be valid: $fileSize bytes');
        return false;
      }

      return true;
    } catch (e) {
      print('Error validating file: $e');
      return false;
    }
  }

// UPDATED: Show media preview with file validation

  void _closePreview() {
    if (!mounted) return;

    _previewVideoController?.dispose();
    _previewVideoController = null;
    setState(() {
      _showPreview = false;
      _previewFile = null;
      _previewImageBytes = null;
      _previewType = null;
    });
  }

  void _retakeMedia() {
    _closePreview();
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!mounted) return;

    final now = DateTime.now();
    if (now.difference(_lastScaleUpdate) < _scaleUpdateThrottle) {
      return; // Throttle updates for performance
    }
    _lastScaleUpdate = now;

    setState(() {
      _scale = (_scale * details.scale).clamp(0.1, 5.0);
      _offsetX += details.focalPointDelta.dx;
      _offsetY += details.focalPointDelta.dy;
    });
  }

  void _toggleOverlay() {
    if (!mounted) return;
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  void _resetComposition() {
    if (!mounted) return;
    setState(() {
      _opacity = 0.7;
      _scale = 1.0;
      _offsetX = 0.0;
      _offsetY = 0.0;
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  // FIXED: Safe capture button handler
  void _handleCaptureButtonPress() {
    if (!mounted || _isProcessing) return;

    if (_captureMode == CaptureMode.photo) {
      _capturePhoto();
    } else {
      if (_isRecording) {
        _stopVideoRecording();
      } else {
        _startVideoRecording();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showPreview) {
      return _buildPreviewScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.photo_library,
              color: Color(0xFF00008b),
            ),
            onPressed: _selectSacredSite,
            tooltip: 'Select Sacred Site',
          ),
          IconButton(
            icon: Icon(
              _captureMode == CaptureMode.photo
                  ? Icons.videocam
                  : Icons.photo_camera,
              color: Colors.grey,
            ),
            onPressed: _switchCaptureMode,
          ),
          IconButton(
            icon: Icon(Icons.cameraswitch, color: Colors.grey),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: _controller == null
          ? _buildLoadingView()
          : _isCameraReady
              ? _buildCameraView()
              : _buildErrorView(),
      floatingActionButton: _isProcessing
          ? Container(
              width: 64,
              height: 64,
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            )
          : _buildCaptureButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildPreviewScreen() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: _retakeMedia,
        ),
        title: Text(
          'プレビュー',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          if (_isSaving)
            Container(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.save, color: Colors.grey),
              onPressed: _saveMedia,
              tooltip: 'ギャラリーに保存',
            ),
        ],
      ),
      body: Center(
        child: _previewType == CaptureType.video
            ? _buildVideoPreview()
            : _buildImagePreview(),
      ),
      bottomNavigationBar: _buildPreviewControls(),
    );
  }

  Widget _buildVideoPreview() {
    if (_previewVideoController == null ||
        !_previewVideoController!.value.isInitialized) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _previewVideoController!.value.aspectRatio,
      child: VideoPlayer(_previewVideoController!),
    );
  }

  Widget _buildImagePreview() {
    if (_previewImageBytes == null) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return InteractiveViewer(
      panEnabled: true,
      scaleEnabled: true,
      child: Image.memory(_previewImageBytes!),
    );
  }

  Widget _buildPreviewControls() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.black.withOpacity(0.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: _retakeMedia,
            icon: Icon(Icons.camera_alt),
            label: Text('リテイク'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00008b),
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveMedia,
            icon: Icon(Icons.save),
            label: Text('ギャラリーに保存'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            SizedBox(height: 16),
            Text('カメラを初期化しています...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        Positioned.fill(
          child: CameraPreview(_controller!),
        ),
        if (_showOverlay && _sacredSiteImageBytes != null && !_isLoadingOverlay)
          Positioned.fill(
            child: GestureDetector(
              onScaleUpdate: _handleScaleUpdate,
              child: OverlayImageWidget(
                imageBytes: _sacredSiteImageBytes!,
                opacity: _opacity,
                scale: _scale,
                offsetX: _offsetX,
                offsetY: _offsetY,
              ),
            ),
          ),
        if (_isLoadingOverlay)
          Positioned.fill(
            child: Container(
              color: Colors.black26,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
        if (_sacredSiteImageBytes != null &&
            _showControls &&
            !_isRecording &&
            !_isProcessing)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: _buildCompositionControls(),
          ),
        if (_captureMode == CaptureMode.video && _isRecording)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam, color: Colors.white, size: 16),
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
        if (_isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '処理...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Text('Camera not ready', style: TextStyle(color: Colors.white)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeCameraController,
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompositionControls() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ピンチでスケール、ドラッグで位置調整',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.opacity, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _opacity,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _opacity = value;
                        });
                      }
                    },
                    activeColor: Colors.blueAccent,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '${(_opacity * 100).round()}%',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.zoom_in, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _scale,
                    min: 0.1,
                    max: 3.0,
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _scale = value;
                        });
                      }
                    },
                    activeColor: Colors.greenAccent,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '${(_scale * 100).round()}%',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 8),
            TextButton.icon(
              onPressed: _resetComposition,
              icon: Icon(Icons.refresh, color: Colors.white, size: 16),
              label: Text(
                'リセット',
                style: TextStyle(color: Colors.white),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ),
      ),
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
          onPressed: _handleCaptureButtonPress, // FIXED: Use safe handler
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

// Widget for overlay rendering with proper image loading
class OverlayImageWidget extends StatefulWidget {
  final Uint8List imageBytes;
  final double opacity;
  final double scale;
  final double offsetX;
  final double offsetY;

  const OverlayImageWidget({
    Key? key,
    required this.imageBytes,
    required this.opacity,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  }) : super(key: key);

  @override
  _OverlayImageWidgetState createState() => _OverlayImageWidgetState();
}

class _OverlayImageWidgetState extends State<OverlayImageWidget> {
  ui.Image? _decodedImage;
  bool _isDecoding = false;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  @override
  void didUpdateWidget(OverlayImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes) {
      _decodeImage();
    }
  }

  Future<void> _decodeImage() async {
    if (_isDecoding) return;

    setState(() {
      _isDecoding = true;
    });

    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _decodedImage = frame.image;
          _isDecoding = false;
        });
      }
    } catch (e) {
      print('Error decoding overlay image: $e');
      if (mounted) {
        setState(() {
          _isDecoding = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _decodedImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_decodedImage == null) {
      return SizedBox.shrink();
    }

    return CustomPaint(
      painter: OverlayPainter(
        image: _decodedImage!,
        opacity: widget.opacity,
        scale: widget.scale,
        offsetX: widget.offsetX,
        offsetY: widget.offsetY,
      ),
      child: Container(),
    );
  }
}

// Custom painter for overlay rendering
class OverlayPainter extends CustomPainter {
  final ui.Image image;
  final double opacity;
  final double scale;
  final double offsetX;
  final double offsetY;

  OverlayPainter({
    required this.image,
    required this.opacity,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..colorFilter = ColorFilter.mode(
        Color.fromRGBO(255, 255, 255, opacity),
        BlendMode.modulate,
      );

    // Calculate scaled dimensions
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();

    // Calculate aspect ratio fit (contain mode)
    final imageAspectRatio = imageWidth / imageHeight;
    final canvasAspectRatio = size.width / size.height;

    double drawWidth, drawHeight;
    if (imageAspectRatio > canvasAspectRatio) {
      drawWidth = size.width * scale;
      drawHeight = drawWidth / imageAspectRatio;
    } else {
      drawHeight = size.height * scale;
      drawWidth = drawHeight * imageAspectRatio;
    }

    // Center the image with offsets
    canvas.save();
    canvas.translate(size.width / 2 + offsetX, size.height / 2 + offsetY);

    final srcRect = Rect.fromLTWH(0, 0, imageWidth, imageHeight);
    final dstRect = Rect.fromCenter(
      center: Offset.zero,
      width: drawWidth,
      height: drawHeight,
    );

    canvas.drawImageRect(image, srcRect, dstRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(OverlayPainter oldDelegate) {
    return oldDelegate.opacity != opacity ||
        oldDelegate.scale != scale ||
        oldDelegate.offsetX != offsetX ||
        oldDelegate.offsetY != offsetY ||
        oldDelegate.image != image;
  }
}
