import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:parts/Prensantionlayer/CameraCompositionScreen/Capturevideo_image.dart';
import 'package:parts/Prensantionlayer/CameraCompositionScreen/ScaredSitebottomsheet.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;

class CameraCompositionScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const CameraCompositionScreen({Key? key, this.onBackPressed})
      : super(key: key);

  @override
  _CameraCompositionScreenState createState() =>
      _CameraCompositionScreenState();
}

class _CameraCompositionScreenState extends State<CameraCompositionScreen> {
  // Media states
  Uint8List? _referenceImageBytes;
  File? _referenceVideoFile;
  Uint8List? _sacredSiteImageBytes;
  Uint8List? _combinedImageBytes;
  File? _processedVideoFile;

  // Media type tracking
  MediaType _referenceMediaType = MediaType.none;
  MediaType _combinedMediaType = MediaType.none;

  // UI state
  bool _isLoading = false;
  bool _isInitializing = true;
  double _opacity = 0.7;
  double _scale = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;
  bool _isSelectingSacredSite = false;

  // Video controllers
  VideoPlayerController? _videoController;
  VideoPlayerController? _processedVideoController;
  bool _isVideoPlaying = true;
  bool _isProcessedVideoPlaying = true;

  // Selected states
  SacredSite? _selectedSacredSite;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _processedVideoController?.dispose();
    super.dispose();
  }

  void _initializeScreen() async {
    setState(() {
      _isInitializing = false;
    });
  }

  // Camera method for reference media
  Future<void> _openCameraForReference() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showErrorSnackBar('No cameras available');
        return;
      }

      final firstCamera = cameras.first;

      if (!mounted) return;

      final CaptureResult? captureResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraCaptureScreen(camera: firstCamera),
        ),
      );

      if (captureResult != null && mounted) {
        if (captureResult.type == CaptureType.photo) {
          final Uint8List imageBytes = await captureResult.file.readAsBytes();
          setState(() {
            _referenceImageBytes = imageBytes;
            _referenceVideoFile = null;
            _referenceMediaType = MediaType.image;
            _resetMediaStates();
          });
          _showSuccessSnackBar('参考画像をキャプチャしました！');
        } else {
          setState(() {
            _referenceVideoFile = captureResult.file;
            _referenceImageBytes = null;
            _referenceMediaType = MediaType.video;
            _resetMediaStates();
          });
          _initializeVideoController(captureResult.file);
          _showSuccessSnackBar('参考動画をキャプチャしました！');
        }
      }
    } catch (e) {
      print('Error opening camera: $e');
      _showErrorSnackBar('Failed to open camera');
    }
  }

  void _initializeVideoController(File videoFile) {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(videoFile)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.play();
          _videoController!.setLooping(true);
        }
      });
  }

  void _initializeProcessedVideoController(File videoFile) {
    _processedVideoController?.dispose();
    _processedVideoController = VideoPlayerController.file(videoFile)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _processedVideoController!.play();
          _processedVideoController!.setLooping(true);
        }
      });
  }

  void _toggleVideoPlayback() {
    if (_videoController != null) {
      setState(() {
        _isVideoPlaying = !_isVideoPlaying;
      });
      if (_isVideoPlaying) {
        _videoController!.play();
      } else {
        _videoController!.pause();
      }
    }
  }

  void _toggleProcessedVideoPlayback() {
    if (_processedVideoController != null) {
      setState(() {
        _isProcessedVideoPlaying = !_isProcessedVideoPlaying;
      });
      if (_isProcessedVideoPlaying) {
        _processedVideoController!.play();
      } else {
        _processedVideoController!.pause();
      }
    }
  }

  // Sacred site selection
  Future<void> _showSacredSiteGrid() async {
    setState(() {
      _isSelectingSacredSite = true;
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SacredSiteBottomSheet(
        selectedSacredSite: _selectedSacredSite,
        onSacredSiteSelected: _loadSacredSiteFromUrl,
      ),
    );

    setState(() {
      _isSelectingSacredSite = false;
    });
  }

  Future<void> _loadSacredSiteFromUrl(SacredSite site) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final HttpClient httpClient = HttpClient();
      final HttpClientRequest request = await httpClient.getUrl(
        Uri.parse(site.imageUrl),
      );
      final HttpClientResponse response = await request.close();

      if (response.statusCode == 200) {
        final Uint8List bytes = await consolidateHttpClientResponseBytes(
          response,
        );
        if (mounted) {
          setState(() {
            _sacredSiteImageBytes = bytes;
            _selectedSacredSite = site;
            _combinedImageBytes = null;
            _processedVideoFile = null;
            _processedVideoController?.dispose();
            _processedVideoController = null;
            _isLoading = false;
          });
          _showSuccessSnackBar('Sacred site "${site.sourceTitle}" selected!');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading sacred site image: $e');
      _showErrorSnackBar('Failed to load sacred site image');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Combination methods
  Future<void> _combineMedia() async {
    if (_referenceMediaType == MediaType.none ||
        _sacredSiteImageBytes == null) {
      _showErrorSnackBar(
        '参考メディアと聖地画像の両方を選択してください',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_referenceMediaType == MediaType.image) {
        await _combineImages();
      } else {
        await _combineVideoWithImage();
      }
    } catch (e) {
      print('Error combining media: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showErrorSnackBar('Failed to combine media');
    }
  }

  Future<void> _combineImages() async {
    try {
      final combinedBytes = await _createCombinedImage();
      if (mounted) {
        setState(() {
          _combinedImageBytes = combinedBytes;
          _combinedMediaType = MediaType.image;
          _isLoading = false;
        });
      }
      _showSuccessSnackBar('画像の結合に成功しました！');
    } catch (e) {
      print('Error combining images: $e');
      rethrow;
    }
  }

  Future<void> _combineVideoWithImage() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Process video with overlay
      await _processVideoWithOverlay();

      // Create preview for UI
      final previewBytes = await _createVideoPreviewWithOverlay();

      if (mounted) {
        setState(() {
          _combinedImageBytes = previewBytes;
          _combinedMediaType = MediaType.video;
          _isLoading = false;
        });
      }
      _showSuccessSnackBar('動画と画像が結合されました！保存準備完了。');
    } catch (e) {
      print('Error combining video with image: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      rethrow;
    }
  }

  Future<Uint8List> _createCombinedImage() async {
    try {
      if (_referenceImageBytes == null || _sacredSiteImageBytes == null) {
        throw Exception('Missing images for combination');
      }

      final codec1 = await instantiateImageCodec(_referenceImageBytes!);
      final frame1 = await codec1.getNextFrame();
      final referenceImage = frame1.image;

      final codec2 = await instantiateImageCodec(_sacredSiteImageBytes!);
      final frame2 = await codec2.getNextFrame();
      final sacredSiteImage = frame2.image;

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Use reference image dimensions
      final double width = referenceImage.width.toDouble();
      final double height = referenceImage.height.toDouble();

      // Draw reference image as background
      canvas.drawImageRect(
        referenceImage,
        Rect.fromLTWH(0, 0, width, height),
        Rect.fromLTWH(0, 0, width, height),
        Paint()..isAntiAlias = true,
      );

      // Draw sacred site image with transformations
      canvas.save();
      canvas.translate(width / 2, height / 2);
      canvas.translate(_offsetX, _offsetY);
      canvas.scale(_scale);

      final sacredSitePaint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high
        ..color = Color.fromRGBO(255, 255, 255, _opacity);

      final double scaledWidth = sacredSiteImage.width.toDouble() * _scale;
      final double scaledHeight = sacredSiteImage.height.toDouble() * _scale;

      canvas.drawImageRect(
        sacredSiteImage,
        Rect.fromLTWH(
          0,
          0,
          sacredSiteImage.width.toDouble(),
          sacredSiteImage.height.toDouble(),
        ),
        Rect.fromCenter(
          center: Offset.zero,
          width: scaledWidth,
          height: scaledHeight,
        ),
        sacredSitePaint,
      );

      canvas.restore();

      final picture = recorder.endRecording();
      final combinedImage = await picture.toImage(
        width.toInt(),
        height.toInt(),
      );
      final byteData = await combinedImage.toByteData(
        format: ImageByteFormat.png,
      );

      return byteData!.buffer.asUint8List();
    } catch (e) {
      print('Error creating combined image: $e');
      rethrow;
    }
  }

  Future<Uint8List> _createVideoPreviewWithOverlay() async {
    try {
      if (_referenceVideoFile == null || _sacredSiteImageBytes == null) {
        throw Exception('Missing video or sacred site image');
      }

      // Create a thumbnail from the video
      final uint8list = await video_thumbnail.VideoThumbnail.thumbnailData(
        video: _referenceVideoFile!.path,
        imageFormat: video_thumbnail.ImageFormat.JPEG,
        quality: 100,
      );

      if (uint8list == null) {
        throw Exception('Could not create video thumbnail');
      }

      final codec1 = await instantiateImageCodec(uint8list);
      final frame1 = await codec1.getNextFrame();
      final videoThumbnail = frame1.image;

      final codec2 = await instantiateImageCodec(_sacredSiteImageBytes!);
      final frame2 = await codec2.getNextFrame();
      final sacredSiteImage = frame2.image;

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Use video thumbnail dimensions
      final double width = videoThumbnail.width.toDouble();
      final double height = videoThumbnail.height.toDouble();

      // Draw video thumbnail as background
      canvas.drawImageRect(
        videoThumbnail,
        Rect.fromLTWH(0, 0, width, height),
        Rect.fromLTWH(0, 0, width, height),
        Paint()..isAntiAlias = true,
      );

      // Draw sacred site overlay
      canvas.save();
      canvas.translate(width / 2, height / 2);
      canvas.translate(_offsetX, _offsetY);
      canvas.scale(_scale);

      final sacredSitePaint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high
        ..color = Color.fromRGBO(255, 255, 255, _opacity);

      final double scaledWidth = sacredSiteImage.width.toDouble() * _scale;
      final double scaledHeight = sacredSiteImage.height.toDouble() * _scale;

      canvas.drawImageRect(
        sacredSiteImage,
        Rect.fromLTWH(
          0,
          0,
          sacredSiteImage.width.toDouble(),
          sacredSiteImage.height.toDouble(),
        ),
        Rect.fromCenter(
          center: Offset.zero,
          width: scaledWidth,
          height: scaledHeight,
        ),
        sacredSitePaint,
      );

      canvas.restore();

      final picture = recorder.endRecording();
      final previewImage = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await previewImage.toByteData(
        format: ImageByteFormat.png,
      );

      return byteData!.buffer.asUint8List();
    } catch (e) {
      print('Error creating video preview: $e');
      rethrow;
    }
  }

  Future<void> _processVideoWithOverlay() async {
    try {
      if (_referenceVideoFile == null || _sacredSiteImageBytes == null) {
        throw Exception('Missing video or sacred site image');
      }

      // Save sacred site image to temporary file
      final tempDir = await getTemporaryDirectory();
      final overlayImagePath =
          '${tempDir.path}/overlay_${DateTime.now().millisecondsSinceEpoch}.png';
      final overlayFile = File(overlayImagePath);
      await overlayFile.writeAsBytes(_sacredSiteImageBytes!);

      // Get video dimensions
      final videoInfo = await _getVideoDimensions(_referenceVideoFile!.path);
      final videoWidth = videoInfo['width'] ?? 1920;
      final videoHeight = videoInfo['height'] ?? 1080;

      // Create output path
      final outputPath =
          '${tempDir.path}/sacred_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Build FFmpeg command for overlay
      final command = _buildOverlayCommand(
        videoPath: _referenceVideoFile!.path,
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

      // Execute FFmpeg command with better error handling
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final logs = await session.getAllLogs();

      print('FFmpeg Return Code: $returnCode');
      for (final log in logs) {
        print('FFmpeg Log: ${log.getMessage()}');
      }

      // Clean up temporary overlay file
      await overlayFile.delete();

      if (ReturnCode.isSuccess(returnCode)) {
        // Verify the output file was created
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          // Initialize the processed video controller for UI display
          _initializeProcessedVideoController(outputFile);

          setState(() {
            _processedVideoFile = outputFile;
          });
          print('Video processed successfully: $outputPath');
        } else {
          throw Exception('Output file was not created');
        }
      } else {
        print('FFmpeg processing failed with return code: $returnCode');
        throw Exception('FFmpeg processing failed');
      }
    } catch (e) {
      print('Error processing video with overlay: $e');
      rethrow;
    }
  }

  // Save methods
  Future<void> _saveCombinedMedia() async {
    if (_combinedMediaType == MediaType.none) {
      _showErrorSnackBar('No combined media to save');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      bool saved = false;

      if (_combinedMediaType == MediaType.image) {
        // Save combined image
        saved = await _saveCombinedImage();
      } else {
        // Save processed video
        saved = await _saveProcessedVideo();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (saved) {
        _showSuccessSnackBar('Media saved to gallery successfully!');
      } else {
        _showErrorSnackBar('Failed to save media to gallery');
      }
    } catch (e) {
      print('Error saving combined media: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showErrorSnackBar('Failed to save media: $e');
    }
  }

  Future<bool> _saveCombinedImage() async {
    try {
      if (_combinedImageBytes == null) {
        throw Exception('No combined image to save');
      }

      final result = await ImageGallerySaver.saveImage(
        _combinedImageBytes!,
        quality: 100,
        name: 'sacred_composition_${DateTime.now().millisecondsSinceEpoch}',
      );

      final bool isSuccess = result['isSuccess'] == true;
      print('Image save result: $result');

      return isSuccess;
    } catch (e) {
      print('Error saving combined image: $e');

      // Fallback to photo_manager if available
      try {
        final AssetEntity? savedAsset = await PhotoManager.editor.saveImage(
          _combinedImageBytes!,
          title: 'sacred_composition_${DateTime.now().millisecondsSinceEpoch}',
          filename:
              'sacred_composition_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        return savedAsset != null;
      } catch (e2) {
        print('Fallback save also failed: $e2');
        return false;
      }
    }
  }

  Future<bool> _saveProcessedVideo() async {
    try {
      if (_processedVideoFile == null || !await _processedVideoFile!.exists()) {
        throw Exception('No processed video file to save');
      }

      // Verify the video is playable before saving
      try {
        final verificationController =
            VideoPlayerController.file(_processedVideoFile!);
        await verificationController.initialize();
        final duration = verificationController.value.duration;
        await verificationController.dispose();

        if (duration.inSeconds == 0) {
          throw Exception('Video has zero duration');
        }
      } catch (e) {
        _showErrorSnackBar('Processed video is corrupted, please try again');
        return false;
      }

      // Use image_gallery_saver to save the video
      final result =
          await ImageGallerySaver.saveFile(_processedVideoFile!.path);

      final bool isSuccess = result['isSuccess'] == true;
      print('Video save result: $result');

      if (isSuccess) {
        // Only delete the temp file after successful save
        await _processedVideoFile!.delete();
        setState(() {
          _processedVideoFile = null;
        });
      }

      return isSuccess;
    } catch (e) {
      print('Error saving processed video: $e');
      return false;
    }
  }

  // Helper method to get video dimensions
  Future<Map<String, int>> _getVideoDimensions(String videoPath) async {
    try {
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      final width = controller.value.size.width.toInt();
      final height = controller.value.size.height.toInt();
      await controller.dispose();

      return {'width': width, 'height': height};
    } catch (e) {
      print('Error getting video dimensions: $e');
      return {'width': 1920, 'height': 1080};
    }
  }

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
    // Calculate overlay dimensions and position
    final overlayWidth = (videoWidth * scale).toInt();
    final overlayHeight = (videoHeight * scale).toInt();

    // Calculate position to center the overlay with offsets
    final overlayX = ((videoWidth - overlayWidth) / 2 + offsetX).toInt();
    final overlayY = ((videoHeight - overlayHeight) / 2 + offsetY).toInt();

    // Ensure coordinates are within bounds
    final safeOverlayX = overlayX.clamp(0, videoWidth - overlayWidth);
    final safeOverlayY = overlayY.clamp(0, videoHeight - overlayHeight);

    // Proper FFmpeg command that handles both video and audio correctly
    return '-i "$videoPath" -i "$imagePath" '
        '-filter_complex "'
        '[0:v]setpts=PTS-STARTPTS[main_video];' // Main video stream
        '[1]format=rgba,scale=$overlayWidth:$overlayHeight,'
        'colorchannelmixer=aa=$opacity[overlay];' // Overlay with opacity
        '[main_video][overlay]overlay=$safeOverlayX:$safeOverlayY:enable=\'between(t,0,1e+6)\'[out_video]" ' // Overlay for entire duration
        '-map "[out_video]" ' // Map the processed video
        '-map "0:a?" ' // Map audio from original video (optional)
        '-c:v libx264 ' // Video codec
        '-preset medium ' // Encoding speed
        '-crf 23 ' // Quality setting
        '-c:a aac ' // Audio codec
        '-b:a 128k ' // Audio bitrate
        '-movflags +faststart ' // Quick start for web
        '-pix_fmt yuv420p ' // Pixel format for compatibility
        '-y ' // Overwrite output file
        '"$outputPath"';
  }

  void _resetMediaStates() {
    setState(() {
      _sacredSiteImageBytes = null;
      _combinedImageBytes = null;
      _processedVideoFile = null;
      _selectedSacredSite = null;
      _processedVideoController?.dispose();
      _processedVideoController = null;
      _opacity = 0.7;
      _scale = 1.0;
      _offsetX = 0.0;
      _offsetY = 0.0;
    });
  }

  void _resetAll() {
    _videoController?.dispose();
    _videoController = null;
    _processedVideoController?.dispose();
    _processedVideoController = null;
    setState(() {
      _referenceImageBytes = null;
      _referenceVideoFile = null;
      _processedVideoFile = null;
      _referenceMediaType = MediaType.none;
      _resetMediaStates();
      _isVideoPlaying = true;
      _isProcessedVideoPlaying = true;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop && widget.onBackPressed != null) {
          widget.onBackPressed!();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isInitializing
            ? _buildInitializingView()
            : Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: _referenceMediaType == MediaType.none
                        ? _buildCameraSelectionView()
                        : _buildCompositionView(),
                  ),
                  _buildBottomControls(),
                ],
              ),
      ),
    );
  }

  Widget _buildInitializingView() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (widget.onBackPressed != null) {
                widget.onBackPressed!();
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          if (_referenceMediaType != MediaType.none)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _resetAll,
            ),
        ],
      ),
    );
  }

  Widget _buildCameraSelectionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _openCameraForReference,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.4),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.camera_alt, color: Colors.white, size: 40),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'キャプチャリファレンス',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '写真を撮ったりビデオを録画したりする',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCompositionView() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return Stack(
      children: [
        // Background media
        if (_referenceMediaType == MediaType.image &&
            _referenceImageBytes != null)
          Positioned.fill(
            child: Image.memory(_referenceImageBytes!, fit: BoxFit.cover),
          ),

        if (_referenceMediaType == MediaType.video && _videoController != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleVideoPlayback,
              child: Stack(
                children: [
                  VideoPlayer(_videoController!),
                  if (!_isVideoPlaying)
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Sacred site overlay (when not combined yet)
        if (_sacredSiteImageBytes != null &&
            _combinedImageBytes == null &&
            _processedVideoFile == null)
          Positioned.fill(
            child: GestureDetector(
              onScaleUpdate: (details) {
                setState(() {
                  _scale = (_scale * details.scale).clamp(0.1, 5.0);
                  _offsetX += details.focalPointDelta.dx;
                  _offsetY += details.focalPointDelta.dy;
                });
              },
              child: Transform(
                transform: Matrix4.identity()
                  ..translate(_offsetX, _offsetY)
                  ..scale(_scale),
                child: Opacity(
                  opacity: _opacity,
                  child: Image.memory(
                    _sacredSiteImageBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

        // Combined result - Shows final processed video or image
        if (_combinedMediaType == MediaType.video &&
            _processedVideoController != null &&
            _processedVideoController!.value.isInitialized)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleProcessedVideoPlayback,
              child: Stack(
                children: [
                  VideoPlayer(_processedVideoController!),
                  if (!_isProcessedVideoPlaying)
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
        else if (_combinedMediaType == MediaType.image &&
            _combinedImageBytes != null)
          Positioned.fill(
            child: Image.memory(_combinedImageBytes!, fit: BoxFit.contain),
          ),

        // Controls overlay
        if (_sacredSiteImageBytes != null &&
            _combinedImageBytes == null &&
            _processedVideoFile == null)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildEditingControls(),
          ),

        // Media type indicator
        if (_combinedImageBytes != null || _processedVideoFile != null)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _combinedMediaType == MediaType.image ? '画像' : 'ビデオ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEditingControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'オーバーレイを調整する',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
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
                    setState(() {
                      _opacity = value;
                    });
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
                    setState(() {
                      _scale = value;
                    });
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
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.black,
      child: _referenceMediaType == MediaType.none
          ? _buildCameraButton()
          : _sacredSiteImageBytes == null
              ? _buildSacredSiteButton()
              : _combinedImageBytes == null && _processedVideoFile == null
                  ? _buildCombineButton()
                  : _buildSaveButton(),
    );
  }

  Widget _buildCameraButton() {
    return GestureDetector(
      onTap: _openCameraForReference,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.camera_alt, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildSacredSiteButton() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showSacredSiteGrid,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
            child: _isSelectingSacredSite
                ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : Icon(Icons.photo_library, color: Colors.white, size: 30),
          ),
        ),
        SizedBox(height: 8),
        Text(
          '聖地を選択',
          style: TextStyle(color: Colors.greenAccent, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildCombineButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _combineMedia,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          '組み合わせる',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.refresh,
          label: 'やり直す',
          onPressed: _resetMediaStates,
          color: Colors.orange,
        ),
        _buildActionButton(
          icon: Icons.save_alt,
          label: '保存',
          onPressed: _saveCombinedMedia,
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 24),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

enum MediaType { none, image, video }
