import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:parts/Prensantionlayer/CameraCompositionScreen/Capturevideo_image.dart';
import 'package:parts/Prensantionlayer/CameraCompositionScreen/sacred_site_model.dart';

// Enums
enum MediaType { none, image, video }

enum CaptureType { photo, video }

// Capture Result Model
class CaptureResult {
  final File file;
  final Uint8List? imageBytes;
  final CaptureType type;
  final Duration? duration;

  CaptureResult({
    required this.file,
    this.imageBytes,
    required this.type,
    this.duration,
  });
}

class CameraCompositionScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const CameraCompositionScreen({Key? key, this.onBackPressed})
      : super(key: key);

  @override
  _CameraCompositionScreenState createState() =>
      _CameraCompositionScreenState();
}

class _CameraCompositionScreenState extends State<CameraCompositionScreen> {
  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Sacred sites
  List<SacredSite> _sacredSites = [];
  List<SacredSite> _nearbySites = [];
  bool _showNearby = false;
  bool _isLoading = true;
  bool _isFetchingLocation = false;

  // Location
  Position? _userPosition;
  final double _radiusKm = 5.0; // Nearby distance radius

  // Scroll
  final ScrollController _scrollController = ScrollController();

  // Media
  Uint8List? _referenceImageBytes;
  File? _referenceVideoFile;
  MediaType _referenceMediaType = MediaType.none;
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = true;

  // Selected site
  SacredSite? _selectedSacredSite;
  Uint8List? _sacredSiteImageBytes;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // Initialize
  Future<void> _initializeScreen() async {
    await _loadSacredSitesFromFirebase();
    await _getUserLocation();
    _filterNearbySites();
    setState(() => _isLoading = false);
  }

  // Load all sites
  Future<void> _loadSacredSitesFromFirebase() async {
    try {
      final snapshot =
          await _firestore.collection('locations').orderBy('locationID').get();

      final List<SacredSite> sites = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return SacredSite(
              id: doc.id,
              imageUrl: data['imageUrl'] ?? '',
              locationID: data['locationID'] ?? '',
              latitude: (data['latitude'] ?? 0).toDouble(),
              longitude: (data['longitude'] ?? 0).toDouble(),
              point: (data['point'] ?? 0).toInt(),
              sourceLink: data['sourceLink'] ?? '',
              sourceTitle: data['sourceTitle'] ?? '',
              subMedia: data['subMedia'] ?? '',
            );
          })
          .where((s) => s.imageUrl.isNotEmpty)
          .toList();

      _sacredSites = sites;
    } catch (e) {
      print('Error loading sacred sites: $e');
    }
  }

  // Get user location
  Future<void> _getUserLocation() async {
    try {
      setState(() => _isFetchingLocation = true);

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar("Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showErrorSnackBar("Location permissions are denied.");
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() => _userPosition = position);
    } catch (e) {
      print('Error getting location: $e');
      _showErrorSnackBar("Failed to get location.");
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  // Filter nearby sites
  void _filterNearbySites() {
    if (_userPosition == null) return;
    _nearbySites = _sacredSites.where((site) {
      final distance = Geolocator.distanceBetween(
            _userPosition!.latitude,
            _userPosition!.longitude,
            site.latitude,
            site.longitude,
          ) /
          1000; // meters → km
      return distance <= _radiusKm;
    }).toList();
  }

  // Load sacred site image
  Future<void> _loadSacredSiteImageFromUrl(SacredSite site) async {
    try {
      setState(() => _isLoading = true);
      String imageUrl = site.imageUrl;
      if (imageUrl.startsWith('gs://')) {
        final ref = _storage.refFromURL(imageUrl);
        imageUrl = await ref.getDownloadURL();
      }

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        setState(() {
          _sacredSiteImageBytes = response.bodyBytes;
          _selectedSacredSite = site;
        });
      }
    } catch (e) {
      print('Error loading image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- CAMERA METHODS ---
  Future<void> _openCameraForReference() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showErrorSnackBar("No cameras available.");
        return;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraCaptureScreen(
            camera: cameras.first,
            initialSacredSite: _selectedSacredSite,
            sacredSiteImageBytes: _sacredSiteImageBytes,
            onSacredSiteSelected: (site) => _loadSacredSiteImageFromUrl(site),
          ),
        ),
      );

      if (result != null && result is CaptureResult) {
        if (result.type == CaptureType.photo) {
          setState(() {
            _referenceImageBytes = result.imageBytes;
            _referenceVideoFile = null;
            _referenceMediaType = MediaType.image;
          });
        } else {
          _initializeVideoController(result.file);
        }
      }
    } catch (e) {
      _showErrorSnackBar("Failed to open camera");
      print(e);
    }
  }

  void _initializeVideoController(File file) {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _referenceVideoFile = file;
            _referenceMediaType = MediaType.video;
          });
          _videoController!.setLooping(true);
          _videoController!.play();
        }
      });
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
            Color(0xFF00008b),
          )),
        ),
      );
    }

    final displayedSites = _showNearby ? _nearbySites : _sacredSites;

    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(),
          if (_isFetchingLocation)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                "Fetching location...",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          Expanded(
            child: _referenceMediaType == MediaType.none
                ? _buildSacredSitesGridView(displayedSites)
                : _buildCompositionView(),
          ),
        ],
      ),
    );
  }

  // Top bar
  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 10.0).copyWith(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.grey),
              onPressed: widget.onBackPressed ?? () => Navigator.pop(context),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: Color(0xFF00008b), shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _openCameraForReference,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sacred Sites Grid
  Widget _buildSacredSitesGridView(List<SacredSite> sites) {
    if (sites.isEmpty) {
      return const Center(
        child: Text(
          "聖地は見つかりませんでした",
          style: TextStyle(color: Colors.black),
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 3 / 4,
      ),
      itemCount: sites.length,
      itemBuilder: (context, index) => _buildSacredSiteCard(sites[index]),
    );
  }

  Widget _buildSacredSiteCard(SacredSite site) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _loadSacredSiteImageFromUrl(site),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                child: _buildImage(site.imageUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                site.sourceTitle.isNotEmpty ? site.sourceTitle : 'Unknown Site',
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
// In your widget
            FutureBuilder<List<Placemark>>(
              future: placemarkFromCoordinates(site.latitude, site.longitude),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Expanded(
                    child: Text(
                      'Loading...',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }

                if (snapshot.hasError ||
                    snapshot.data == null ||
                    snapshot.data!.isEmpty) {
                  return Expanded(
                    child: Text(
                      'Unknown Location',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }

                final placemark = snapshot.data!.first;
                final locationName = placemark.locality ??
                    placemark.subAdministrativeArea ??
                    placemark.administrativeArea ??
                    'Unknown Location';

                return Expanded(
                  child: Text(
                    locationName,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.startsWith('gs://')) {
      try {
        final ref = _storage.refFromURL(imageUrl);
        return FutureBuilder<String>(
          future: ref.getDownloadURL(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _buildImagePlaceholder();
            }
            return Image.network(snapshot.data!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _buildImagePlaceholder(),
                errorBuilder: (_, __, ___) => _buildImageError());
          },
        );
      } catch (_) {
        return _buildImageError();
      }
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : _buildImagePlaceholder(),
      errorBuilder: (_, __, ___) => _buildImageError(),
    );
  }

  Widget _buildImagePlaceholder() => Container(
        color: Colors.grey[800],
        child: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00008b))),
        ),
      );

  Widget _buildImageError() => Container(
        color: Colors.grey[800],
        child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 40)),
      );

  Widget _buildCompositionView() {
    if (_referenceMediaType == MediaType.image &&
        _referenceImageBytes != null) {
      return Image.memory(_referenceImageBytes!, fit: BoxFit.cover);
    } else if (_referenceMediaType == MediaType.video &&
        _videoController != null) {
      return GestureDetector(
        onTap: () {
          setState(() => _isVideoPlaying = !_isVideoPlaying);
          _isVideoPlaying
              ? _videoController!.play()
              : _videoController!.pause();
        },
        child: Stack(
          children: [
            VideoPlayer(_videoController!),
            if (!_isVideoPlaying)
              const Center(
                  child: Icon(Icons.play_arrow, size: 60, color: Colors.white))
          ],
        ),
      );
    }
    return const SizedBox();
  }

  // SnackBar helpers
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          backgroundColor: Colors.red,
          content: Text(message),
          duration: const Duration(seconds: 3)),
    );
  }
}
