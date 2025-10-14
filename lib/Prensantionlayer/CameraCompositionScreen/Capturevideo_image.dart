import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:parts/Dataprovider/model/sacred_site_model.dart';
import 'package:parts/Prensantionlayer/CameraCompositionScreen/ScaredSitebottomsheet.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:photo_manager/photo_manager.dart';

// Enums for capture types
enum CaptureType { photo, video }

enum AppMode { gallery, composition }

class CameraCaptureScreen extends StatefulWidget {
  final SacredSite? initialSacredSite;
  final Uint8List? sacredSiteImageBytes;
  final Function(SacredSite)? onSacredSiteSelected;

  const CameraCaptureScreen({
    super.key,
    this.initialSacredSite,
    this.sacredSiteImageBytes,
    this.onSacredSiteSelected,
  });

  @override
  _CameraCaptureScreenState createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  // App mode
  AppMode _appMode = AppMode.gallery;

  // Selected media from gallery
  File? _selectedMediaFile;
  CaptureType? _selectedMediaType;

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

  // Gallery states
  List<AssetEntity> _galleryAssets = [];
  bool _isLoadingGallery = false;
  Map<String, Uint8List> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _initializeSacredSiteData();
    _loadGalleryAssets();
  }

  void _initializeSacredSiteData() {
    if (widget.sacredSiteImageBytes != null) {
      setState(() {
        _sacredSiteImageBytes = widget.sacredSiteImageBytes;
        _selectedSacredSite = widget.initialSacredSite;
        _showOverlay = true;
      });
    } else if (widget.initialSacredSite != null) {
      _selectedSacredSite = widget.initialSacredSite;
      _loadSacredSiteImage(widget.initialSacredSite!);
    }
  }

  @override
  void dispose() {
    _previewVideoController?.dispose();
    super.dispose();
  }

  // Load gallery assets
  Future<void> _loadGalleryAssets() async {
    if (!mounted) return;

    setState(() {
      _isLoadingGallery = true;
    });

    try {
      // Request permission
      final PermissionState permission =
          await PhotoManager.requestPermissionExtend();

      if (!permission.isAuth) {
        _showErrorSnackBar(
            'Gallery permission denied. Please enable in settings.');
        return;
      }

      // Fetch assets from gallery
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );

      if (albums.isNotEmpty) {
        final AssetPathEntity recentAlbum = albums.first;
        final List<AssetEntity> assets = await recentAlbum.getAssetListRange(
          start: 0,
          end: 100, // Load first 100 assets
        );

        if (mounted) {
          setState(() {
            _galleryAssets = assets;
            _isLoadingGallery = false;
          });
        }
      } else {
        throw Exception('No albums found');
      }
    } catch (e) {
      print('Error loading gallery assets: $e');
      if (mounted) {
        setState(() {
          _isLoadingGallery = false;
        });
        _showErrorSnackBar('Failed to load gallery: ${e.toString()}');
      }
    }
  }

  // Enhanced thumbnail loading with caching
  Future<Uint8List?> _loadThumbnail(AssetEntity asset,
      {ThumbnailSize size = const ThumbnailSize(200, 200)}) async {
    final cacheKey = '${asset.id}_${size.width}x${size.height}';

    // Return cached thumbnail if available
    if (_thumbnailCache.containsKey(cacheKey)) {
      return _thumbnailCache[cacheKey];
    }

    try {
      final thumbnail = await asset.thumbnailDataWithSize(
        size,
        quality: 80,
      );

      if (thumbnail != null) {
        // Cache the thumbnail
        _thumbnailCache[cacheKey] = thumbnail;
        return thumbnail;
      }
    } catch (e) {
      print('Error loading thumbnail for ${asset.id}: $e');
    }

    return null;
  }

  // Handle gallery item selection - just select the media
  Future<void> _handleGalleryItemTap(AssetEntity asset) async {
    if (!mounted || _isProcessing) return;

    try {
      setState(() {
        _isProcessing = true;
        _selectedMediaType = asset.type == AssetType.video
            ? CaptureType.video
            : CaptureType.photo;
      });

      // Load the actual file
      final File? file = await asset.originFile;
      if (file == null) {
        throw Exception('Could not load file from gallery');
      }

      // Verify file exists and has content
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File is empty');
      }

      setState(() {
        _selectedMediaFile = file;
        _isProcessing = false;
        _appMode = AppMode.composition;
      });

      _showSuccessSnackBar(
          'Media selected. Now choose a sacred site to combine.');
    } catch (e) {
      print('Error selecting gallery item: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to select media: ${e.toString()}');
        setState(() {
          _isProcessing = false;
          _selectedMediaFile = null;
        });
      }
    }
  }

  // Create composition with selected media and sacred site
  Future<void> _createComposition() async {
    if (_selectedMediaFile == null) {
      _showErrorSnackBar('Please select a media file first');
      return;
    }

    if (_sacredSiteImageBytes == null) {
      _showErrorSnackBar('Please select a sacred site first');
      return;
    }

    if (!mounted || _isProcessing) return;

    try {
      setState(() {
        _isProcessing = true;
      });

      if (_selectedMediaType == CaptureType.photo) {
        // Handle image composition
        final File finalImageFile =
            await _createComposedImage(_selectedMediaFile!);
        final Uint8List finalImageBytes = await finalImageFile.readAsBytes();
        _showMediaPreview(finalImageFile, finalImageBytes, CaptureType.photo);
      } else {
        // Handle video composition
        await _processVideoWithOverlay(_selectedMediaFile!);
      }
    } catch (e) {
      print('Error creating composition: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to create composition: ${e.toString()}');
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Build gallery grid view
  Widget _buildGalleryGridView() {
    if (_isLoadingGallery) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'ギャラリーを読み込んでいます...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_galleryAssets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, color: Colors.white54, size: 64),
            SizedBox(height: 16),
            Text(
              'メディアが見つかりません',
              style: TextStyle(color: Colors.white54),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadGalleryAssets,
              child: Text('リトライ'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _galleryAssets.length,
      itemBuilder: (context, index) {
        return _buildGalleryItem(_galleryAssets[index]);
      },
    );
  }

  // Build individual gallery item
  Widget _buildGalleryItem(AssetEntity asset) {
    return FutureBuilder<Uint8List?>(
      future: _loadThumbnail(asset),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return Container(
            color: Colors.grey[800],
            child: Icon(Icons.photo, color: Colors.white54),
          );
        }

        return GestureDetector(
          onTap: () => _handleGalleryItemTap(asset),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                bytes,
                fit: BoxFit.cover,
              ),
              if (asset.type == AssetType.video)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showPreview) {
      return _buildPreviewScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: _appMode == AppMode.gallery
          ? _buildGalleryView()
          : _buildCompositionView(),
      floatingActionButton:
          _appMode == AppMode.composition ? _buildComposeButton() : null,
    );
  }

  // AppBar with mode switching
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.grey),
        onPressed: () {
          if (_appMode == AppMode.composition || _showPreview) {
            _resetEverything();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Text(
        _appMode == AppMode.gallery ? 'メディアを選択' : 'コンポジションを作成する',
        style: TextStyle(color: Colors.white),
      ),
      actions: [
        if (_appMode == AppMode.composition)
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey),
            onPressed: _resetComposition,
            tooltip: '',
          ),
        IconButton(
          icon: Icon(
            Icons.temple_buddhist,
            color: Color(0xFF00008b),
          ),
          onPressed: _selectSacredSite,
          tooltip: '聖地を選択',
        ),
      ],
    );
  }

  // Reset everything to initial state
  void _resetEverything() {
    // Dispose video controller if exists
    _previewVideoController?.dispose();
    _previewVideoController = null;

    setState(() {
      // Reset app mode
      _appMode = AppMode.gallery;

      // Reset media selection
      _selectedMediaFile = null;
      _selectedMediaType = null;

      // Reset to initial sacred site data
      _selectedSacredSite = widget.initialSacredSite;
      _sacredSiteImageBytes = widget.sacredSiteImageBytes;

      // Reset composition controls to defaults
      _opacity = 0.7;
      _scale = 1.0;
      _offsetX = 0.0;
      _offsetY = 0.0;
      _showOverlay = true;
      _showControls = true;

      // Reset processing states
      _isProcessing = false;
      _isSaving = false;
      _isLoadingOverlay = false;

      // Reset preview states
      _showPreview = false;
      _previewFile = null;
      _previewImageBytes = null;
      _previewType = null;

      // Reset gallery cache
      _thumbnailCache.clear();
    });

    // If we have an initial sacred site but no image bytes, load it
    if (widget.initialSacredSite != null && _sacredSiteImageBytes == null) {
      _loadSacredSiteImage(widget.initialSacredSite!);
    }
  }

  // Build composition view
  Widget _buildCompositionView() {
    return Stack(
      children: [
        // Media preview
        Positioned.fill(
          child: _selectedMediaType == CaptureType.video
              ? _buildVideoPreview()
              : _buildImagePreview(),
        ),

        // Sacred site overlay
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

        // Loading overlay - only show one loading indicator
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
                      _getLoadingText(),
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

        // Composition controls
        if (_sacredSiteImageBytes != null && _showControls && !_isProcessing)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: _buildCompositionControls(),
          ),

        // Media info
        Positioned(
          left: 0,
          right: 0,
          child: Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedMediaType == CaptureType.video
                      ? Icons.videocam
                      : Icons.photo,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Get appropriate loading text based on current operation
  String _getLoadingText() {
    if (_isSaving) return 'ギャラリーに保存しています...';
    if (_isProcessing && _selectedMediaType == CaptureType.video)
      return 'ビデオを処理中...';
    if (_isProcessing) return 'コンポジションを作成しています...';
    return '処理...';
  }

  // Video preview for composition
  Widget _buildVideoPreview() {
    if (_selectedMediaFile == null) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return FutureBuilder(
      future: _initializeVideoController(_selectedMediaFile!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        return AspectRatio(
          aspectRatio: snapshot.data?.value.aspectRatio ?? 16 / 9,
          child: VideoPlayer(snapshot.data!),
        );
      },
    );
  }

  Future<VideoPlayerController> _initializeVideoController(File file) async {
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    controller.setLooping(true);
    controller.play();
    return controller;
  }

  Widget _buildGalleryView() {
    return Stack(
      children: [
        // Main gallery grid
        Positioned.fill(
          child: _buildGalleryGridView(),
        ),

        // Sacred site overlay (shown on top of gallery for preview)
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

        // Loading indicator for sacred site
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

        // Composition controls (opacity, scale sliders)
        if (_sacredSiteImageBytes != null && _showControls && !_isProcessing)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: _buildCompositionControls(),
          ),

        // Single processing overlay - don't show multiple loaders
        if (_isProcessing && !_isLoadingOverlay)
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
                      _getLoadingText(),
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

  // Image preview for composition
  Widget _buildImagePreview() {
    if (_selectedMediaFile == null) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return FutureBuilder<Uint8List>(
      future: _selectedMediaFile!.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        if (snapshot.hasData) {
          return InteractiveViewer(
            panEnabled: true,
            scaleEnabled: true,
            child: Image.memory(snapshot.data!),
          );
        }

        return Center(
          child: Text(
            '画像の読み込みに失敗しました',
            style: TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }

  // Compose button
  Widget _buildComposeButton() {
    return FloatingActionButton.extended(
      backgroundColor: _isProcessing ? Colors.grey : Colors.blue,
      onPressed: _isProcessing ? null : _createComposition,
      icon: _isProcessing
          ? CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            )
          : Icon(Icons.auto_awesome, color: Colors.white, size: 28),
      label: Text(
        'コンポジションを作成する',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      tooltip: 'メディアと聖地の融合',
    );
  }

  // Sacred site selection and loading methods
  Future<void> _selectSacredSite() async {
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

        if (_appMode == AppMode.gallery) {
          _showSuccessSnackBar(
              'Sacred site loaded. Now select a media to combine.');
        }
      }
    } catch (e) {
      print('Error showing sacred site bottom sheet: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to open sacred site selector');
      }
    }
  }

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

        if (imageBytes.isNotEmpty) {
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

  // Image composition with sacred site overlay
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

  // Video processing with sacred site overlay
  Future<void> _processVideoWithOverlay(File originalVideo) async {
    try {
      // Don't set _isProcessing here - it's already set in _createComposition

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

      // Build FFmpeg command for overlay
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

  // Preview methods
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
              _isProcessing = false; // Reset processing state
            });
            _previewVideoController!.play();
            _previewVideoController!.setLooping(true);
          }
        }).catchError((e) {
          print('Error initializing video preview: $e');
          if (mounted) {
            setState(() {
              _isProcessing = false; // Reset processing state even on error
            });
          }
        });
    } else {
      setState(() {
        _previewFile = file;
        _previewImageBytes = imageBytes;
        _previewType = type;
        _showPreview = true;
        _isProcessing = false; // Reset processing state
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
          _resetEverything();
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

  // Preview screen
  Widget _buildPreviewScreen() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () {
            _resetEverything();
          },
          tooltip: '作曲に戻る',
        ),
        title: Text(
          'プレビュー構成',
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
              icon: Icon(Icons.save_alt, color: Colors.grey),
              onPressed: _saveMedia,
              tooltip: 'ギャラリーに保存',
            ),
        ],
      ),
      body: Center(
        child: _previewType == CaptureType.video
            ? _buildVideoPreviewScreen()
            : _buildImagePreviewScreen(),
      ),
      bottomNavigationBar: _buildPreviewControls(),
    );
  }

  Widget _buildVideoPreviewScreen() {
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

  Widget _buildImagePreviewScreen() {
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
            onPressed: () {
              _resetEverything();
            },
            icon: Icon(Icons.arrow_back),
            label: Text('編集に戻る'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00008b),
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveMedia,
            icon: Icon(Icons.save_alt),
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
                Icon(Icons.touch_app, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pinch to scale, drag to position overlay',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _toggleOverlay,
                  icon: Icon(
                    _showOverlay ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: Text(
                    _showOverlay ? 'オーバーレイを非表示' : 'オーバーレイを表示',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                TextButton.icon(
                  onPressed: _resetComposition,
                  icon: Icon(Icons.settings_backup_restore,
                      color: Colors.white, size: 16),
                  label: Text(
                    '設定をリセット',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
