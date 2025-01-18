import 'dart:async';
import 'dart:io' show Platform;

import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' hide Marker;
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parts/src/bubble.dart';
import 'package:parts/src/bubble_border.dart';
import 'package:share/share.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'anime_detail.dart';

class AnimeDetailsPage extends StatefulWidget {
  final String animeName;

  AnimeDetailsPage({required this.animeName});

  @override
  _AnimeDetailsPageState createState() => _AnimeDetailsPageState();
}

class _AnimeDetailsPageState extends State<AnimeDetailsPage> {
  late Future<DocumentSnapshot> _animeData;
  OverlayEntry? _overlayEntry;
  final GlobalKey _infoIconKey = GlobalKey();
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isFavorite = false;
  bool _isLoadingMoreReviews = false;
  YoutubePlayerController? _youtubeController;
  bool _showVideo = false;
  bool _videoInitialized = false;
  String? _videoId;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _animeData = _fetchAnimeData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorialTooltip());
  }

  Future<DocumentSnapshot> _fetchAnimeData() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('animes')
          .where('name', isEqualTo: widget.animeName)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot doc = querySnapshot.docs.first;
        if (mounted) {
          _initializeVideo(doc.data() as Map<String, dynamic>);
        }
        return doc;
      } else {
        throw Exception('Anime not found');
      }
    } catch (e) {
      print("Error in _fetchAnimeData: $e");
      rethrow;
    }
  }

  Future<void> _initializeVideo(Map<String, dynamic> animeData) async {
    if (animeData['officialVideoUrl'] != null &&
        animeData['officialVideoUrl'].toString().isNotEmpty) {
      try {
        String originalUrl = animeData['officialVideoUrl'];
        String? videoId = YoutubePlayer.convertUrlToId(originalUrl);
        print("Attempting to initialize video with URL: $originalUrl");
        print("Extracted video ID: $videoId");

        if (videoId != null) {
          setState(() {
            _videoId = videoId;
            _youtubeController = YoutubePlayerController(
              initialVideoId: videoId,
              flags: YoutubePlayerFlags(
                mute: _isMuted,
                autoPlay: true,
                hideControls: true,
                enableCaption: false,
                isLive: false,
                loop: true,
                forceHD: false,
              ),
            );
            _videoInitialized = true;
          });

          await Future.delayed(Duration(seconds: 1));
          if (mounted) {
            setState(() {
              _showVideo = true;
            });
          }
        }
      } catch (e) {
        print("Error initializing video: $e");
        if (mounted) {
          setState(() {
            _videoInitialized = false;
            _showVideo = false;
          });
        }
      }
    }
  }

  Widget _buildHeaderImage(String imageUrl) {
    if (_showVideo && _videoInitialized && _youtubeController != null) {
      return Container(
        height: 200,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 200,
              child: YoutubePlayer(
                controller: _youtubeController!,
                showVideoProgressIndicator: false,
                onReady: () {
                  print("ローディング中...");
                },
                onEnded: (YoutubeMetaData metaData) {
                  _youtubeController?.seekTo(Duration.zero);
                  _youtubeController?.play();
                },
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isMuted = !_isMuted;
                    if (_isMuted) {
                      _youtubeController?.mute();
                    } else {
                      _youtubeController?.unMute();
                    }
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white.withOpacity(0.7),
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Image.network(
      imageUrl,
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
      loadingBuilder: (BuildContext context, Widget child,
          ImageChunkEvent? loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: double.infinity,
          height: 200,
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: 200,
          color: Colors.grey[300],
          child: Center(
            child: Icon(Icons.error, color: Colors.grey[600]),
          ),
        );
      },
    );
  }

  Widget _buildNetworkImage(String imageUrl,
      {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    return imageUrl.isNotEmpty
        ? Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            loadingBuilder: (BuildContext context, Widget child,
                ImageChunkEvent? loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: width,
                height: height,
                color: Colors.grey[200],
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: Center(
                  child: Icon(Icons.error, color: Colors.grey[600]),
                ),
              );
            },
          )
        : Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
            ),
          );
  }

  void _showTutorialTooltip() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    Timer(Duration(seconds: 2), () {
      _removeOverlay();
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final RenderBox? renderBox =
            _infoIconKey.currentContext?.findRenderObject() as RenderBox?;
        final size = renderBox?.size ?? Size.zero;
        final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

        final screenSize = MediaQuery.of(context).size;
        const tooltipWidth = 200.0;
        const tooltipHeight = 40.0;

        double left = offset.dx - tooltipWidth + size.width;
        double top = offset.dy + size.height + 5.0;

        if (left + tooltipWidth > screenSize.width) {
          left = screenSize.width - tooltipWidth - 10.0;
        }

        if (top + tooltipHeight > screenSize.height) {
          top = offset.dy - tooltipHeight - 5.0;
        }

        return Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: tooltipWidth,
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                'タップしてアニメの詳細を見る↑',
                style: TextStyle(color: Colors.white, fontSize: 12.0),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchLocationsForAnime() async {
    List<Map<String, dynamic>> locations = [];
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .where('animeName', isEqualTo: widget.animeName)
          .get();

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // デバッグ出力を追加
        print('==== Fetched Location Data ====');
        print('Document ID: ${doc.id}');
        print('spot_description: ${data['spot_description']}');
        print('============================');

        List<Map<String, dynamic>> processedSubMedia = [];
        var rawSubMedia = data['subMedia'];
        if (rawSubMedia != null) {
          if (rawSubMedia is Map) {
            processedSubMedia.add(Map<String, dynamic>.from(rawSubMedia));
          } else if (rawSubMedia is List) {
            processedSubMedia = (rawSubMedia as List)
                .where((item) => item is Map)
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          }
        }

        locations.add({
          'id': doc.id,
          'title': data['title'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'description': data['description'] ?? '',
          'spot_description':
              data['spot_description'] ?? '', // spot_descriptionを追加
          'latitude': data['latitude'] ?? 0.0,
          'longitude': data['longitude'] ?? 0.0,
          'sourceTitle': data['sourceTitle'] ?? '',
          'subsourceTitle': data['subsourceTitle'] ?? '',
          'sourceLink': data['sourceLink'] ?? '',
          'subsourceLink': data['subsourceLink'] ?? '',
          'url': data['url'] ?? '',
          'subMedia': processedSubMedia,
          'userEmail': data['userEmail'] ?? [],
        });
      }
    } catch (e) {
      print("Error fetching locations: $e");
    }
    return locations;
  }

  @override
  void dispose() {
    _removeOverlay();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.animeName,
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            key: _infoIconKey,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnimeDetail(
                    animeName: widget.animeName,
                  ),
                ),
              );
            },
            icon: Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF00008b),
            ),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _animeData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Anime not found'));
          }

          Map<String, dynamic> animeData =
              snapshot.data!.data() as Map<String, dynamic>;
          String imageUrl = animeData['imageUrl'] ?? '';
          String userId = animeData['userId'] ?? '';

          return Column(
            children: [
              _buildHeaderImage(imageUrl),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    userId.isNotEmpty ? '投稿者: @$userId' : 'エラー',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchLocationsForAnime(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                          child: Text(
                              'No locations found for ${widget.animeName}.'));
                    }

                    final locations = snapshot.data!;
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.3,
                        mainAxisSpacing: 10.0,
                        crossAxisSpacing: 10.0,
                      ),
                      itemCount: locations.length,
                      itemBuilder: (context, index) {
                        final location = locations[index];
                        return _buildLocationCard(location, context);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLocationCard(
      Map<String, dynamic> location, BuildContext context) {
    // デバッグ出力を追加
    print('==== Location Card Data ====');
    print('Raw location data: $location');
    print('============================');

    final String title = location['title'] as String? ?? '';
    final String imageUrl = location['imageUrl'] as String? ?? '';
    final String locationId = location['id'] as String? ?? '';
    final String description = location['description'] as String? ?? '';
    final String spot_description =
        location['spot_description'] as String? ?? '';
    final double latitude = (location['latitude'] as num?)?.toDouble() ?? 0.0;
    final double longitude = (location['longitude'] as num?)?.toDouble() ?? 0.0;
    final String sourceTitle = location['sourceTitle'] as String? ?? '';
    final String subsourceTitle = location['subsourceTitle'] as String? ?? '';
    final String sourceLink = location['sourceLink'] as String? ?? '';
    final String subsourceLink = location['subsourceLink'] as String? ?? '';
    final String url = location['url'] as String? ?? '';
    final userEmail = location['userEmail'];

    // spot_descriptionのデバッグ出力
    print('==== Spot Description Debug ====');
    print('spot_description: $spot_description');
    print('spot_description type: ${spot_description.runtimeType}');
    print('spot_description length: ${spot_description.length}');
    print('=============================');

    String userId;
    if (userEmail is List) {
      userId = userEmail.isNotEmpty
          ? userEmail[0].toString().split('@')[0]
          : 'unknown';
    } else if (userEmail is String) {
      userId = userEmail.split('@')[0];
    } else {
      userId = 'unknown';
    }

    List<Map<String, dynamic>> subMedia = [];
    if (location['subMedia'] != null) {
      if (location['subMedia'] is List) {
        subMedia = (location['subMedia'] as List)
            .where((item) => item is Map<String, dynamic>)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    return GestureDetector(
      onTap: () {
        // SpotDetailScreen遷移時のデバッグ出力
        print('==== Navigation Data ====');
        print(
            'Navigating to SpotDetailScreen with spot_description: $spot_description');
        print('=======================');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SpotDetailScreen(
              title: title,
              imageUrl: imageUrl,
              userId: userId,
              description: description,
              spot_description: spot_description,
              latitude: latitude,
              longitude: longitude,
              sourceLink: sourceLink,
              subsourceLink: subsourceLink,
              sourceTitle: sourceTitle,
              subsourceTitle: subsourceTitle,
              url: url,
              subMedia: subMedia,
              locationId: locationId,
              animeName: widget.animeName,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9.0),
              child: _buildNetworkImage(
                imageUrl,
                width: 200,
                height: 100,
              ),
            ),
            SizedBox(height: 4.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2.0),
            Text(
              '投稿者:@$userId',
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            )
          ],
        ),
      ),
    );
  }
}

class SpotDetailScreen extends StatefulWidget {
  final String title;
  final String description;
  final String spot_description;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String sourceTitle;
  final String subsourceTitle;
  final String sourceLink;
  final String subsourceLink;
  final String url;
  final List<Map<String, dynamic>> subMedia;
  final String locationId;
  final String animeName;
  final String userId;

  const SpotDetailScreen({
    Key? key,
    required this.title,
    required this.description,
    this.spot_description = '', // Provide default value
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    this.sourceTitle = '', // Provide default value
    this.subsourceTitle = '',//this is sub source Title
    this.sourceLink = '', // Provide default value
    this.subsourceLink = '',//this is sub source link
    this.url = '', // Provide default value
    required this.subMedia,
    required this.locationId,
    required this.animeName,
    required this.userId,
  }) : super(key: key);

  @override
  _SpotDetailScreenState createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isFavorite = false;
  bool _isVideoInitialized = false;

  void _shareContent() {
    final String mapsUrl =
        "https://www.google.com/maps/search/?api=1&query=${widget
        .latitude},${widget.longitude}";
    final String shareText = '''
『${widget.animeName}』の聖地
${widget.title}

場所を確認する：
$mapsUrl

素晴らしい聖地巡礼はこちら：
https://japananimemaps.page.link/ios
''';

    Share.share(shareText);
  }

  Future<void> _openMapOptions(BuildContext context) async {
    final googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=${widget
        .latitude},${widget.longitude}";
    final appleMapsUrl =
        "http://maps.apple.com/?q=${widget.latitude},${widget.longitude}";

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.map),
                title: Text('Google Maps'),
                onTap: () async {
                  if (await canLaunch(googleMapsUrl)) {
                    await launch(googleMapsUrl);
                  }
                },
              ),
              if (Platform.isIOS)
                ListTile(
                  leading: Icon(Icons.map),
                  title: Text('Apple Maps'),
                  onTap: () async {
                    if (await canLaunch(appleMapsUrl)) {
                      await launch(appleMapsUrl);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeMedia();
    _checkIfFavorite();
  }

  Future<Map<String, String>> _getAddress() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.latitude,
        widget.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String postalCode = place.postalCode ?? '';
        String address =
            '${place.administrativeArea ?? ''} ${place.locality ?? ''} ${place
            .street ?? ''}';

        return {
          'postalCode': postalCode,
          'address': address,
        };
      }
    } catch (e) {
      print('Error getting address: $e');
    }

    return {
      'postalCode': '取得できませんでした',
      'address': '取得できませんでした',
    };
  }

  Future<void> _initializeMedia() async {
    if (widget.url.isNotEmpty && widget.url.toLowerCase().endsWith('.mp4')) {
      await _initializeVideoPlayer(widget.url);
      return;
    }

    if (!_isVideoInitialized) {
      for (var subMedia in widget.subMedia) {
        if (subMedia['type'] == 'video' && subMedia['url'] != null) {
          await _initializeVideoPlayer(subMedia['url']);
          break;
        }
      }
    }
  }

  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.locationId.isNotEmpty) {
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .doc(widget.locationId)
            .get();

        setState(() {
          _isFavorite = docSnapshot.exists;
        });
      } catch (e) {
        print('Error checking favorite status: $e');
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.locationId.isNotEmpty) {
      try {
        final favoriteRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .doc(widget.locationId);

        setState(() {
          _isFavorite = !_isFavorite;
        });

        if (_isFavorite) {
          await favoriteRef.set({
            'locationId': widget.locationId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          await favoriteRef.delete();
        }
      } catch (e) {
        print('Error toggling favorite: $e');
        setState(() {
          _isFavorite = !_isFavorite;
        });
      }
    }
  }

  Future<void> _initializeVideoPlayer(String url) async {
    try {
      _videoPlayerController = VideoPlayerController.network(url);
      await _videoPlayerController!.initialize();

      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: false,
          looping: true,
          placeholder: Center(child: CircularProgressIndicator()),
          allowPlaybackSpeedChanging: false,
        );
        _isVideoInitialized = true;
      });
    } catch (e) {
      print("Error initializing video player: $e");
      _isVideoInitialized = false;
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Widget _buildMainContent() {
    if (_isVideoInitialized &&
        _chewieController != null &&
        _videoPlayerController != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _videoPlayerController!.value.aspectRatio,
              child: Chewie(controller: _chewieController!),
            ),
            if (!_videoPlayerController!.value.isInitialized)
              CircularProgressIndicator(),
          ],
        ),
      );
    }

    if (widget.url.isNotEmpty && !widget.url.toLowerCase().endsWith('.mp4')) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildNetworkImage(
          widget.url,
          height: 200,
          width: double.infinity,
        ),
      );
    }

    return SizedBox.shrink();
  }

  Widget _buildSubMediaContent() {
    if (_isVideoInitialized) {
      return SizedBox.shrink();
    }

    if (widget.subMedia.isNotEmpty) {
      final firstMedia = widget.subMedia.first;
      if (firstMedia['type'] == 'image' && firstMedia['url'] != null) {
        return _buildNetworkImage(
          firstMedia['url'],
          height: 200,
          width: double.infinity,
        );
      }
    }

    return SizedBox.shrink();
  }

  Widget _buildNetworkImage(String imageUrl,
      {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    return imageUrl.isNotEmpty
        ? Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (BuildContext context, Widget child,
          ImageChunkEvent? loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: Center(
            child: Icon(Icons.error, color: Colors.grey[600]),
          ),
        );
      },
    )
        : Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Center(
        child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locationId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Error'),
        ),
        body: Center(
          child: Text('Error: Invalid location ID'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          '詳細',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: Icon(CupertinoIcons.share_up),
            onPressed: _shareContent,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  widget.title,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '『${widget.animeName}』のスポット',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '投稿者：@${widget.userId}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey,
                      ),
                    )
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildNetworkImage(
                widget.imageUrl,
                width: double.infinity,
                height: 200,
              ),
            ),
            _buildSourceInfo2(),
            const SizedBox(
              height: 10.0,
            ),
            Stack(
              children: [
                Container(
                  margin: EdgeInsets.only(
                      top: 20, right: 20, left: 20), // 上部のスペースを確保
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Color(0xFFF407FED)),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey,
                        spreadRadius: 5,
                        blurRadius: 10,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 18.0,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 6, right: 8),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.description,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10.0,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: ShapeDecoration(
                      color: Color(0xFFF407FED),
                      shape: BubbleBorder(),
                      shadows: [
                        BoxShadow(
                          color: Color(0xFFF407FED).withOpacity(0.5),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '『${widget.animeName}』での登場シーン',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
// buildメソッド内の関連部分
            _buildMainContent(),
            if (widget.subMedia.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildSubMediaContent(),
              ),
            if (widget.subMedia.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(widget.latitude, widget.longitude),
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: MarkerId('spot_location'),
                        position: LatLng(widget.latitude, widget.longitude),
                      ),
                    },
                  ),
                ),
              ),
            _buildSourceInfo1(),
            _buildAddressCard(),
            const SizedBox(
              height: 20.0,
            ),

            // Center(
            //   child: Container(
            //     width: 350,
            //     child: Padding(
            //       padding: EdgeInsets.all(20),
            //       child: Text(
            //         widget.description,
            //         style: GoogleFonts.notoSerif(
            //           // notoSerifJP から notoSerif に変更
            //           fontSize: 16,
            //           color: Colors.black,
            //           // fontWeight: FontWeight.w900,
            //         ),
            //       ),
            //     ),
            //   ),
            // ),
            //囲みありの場合↓
            // Container(
            //   margin:
            //       EdgeInsets.only(top: 20, right: 20, left: 20), // Stackと同じマージン
            //   padding: EdgeInsets.all(16),
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //     border: Border.all(color: Color(0xFFF407FED)),
            //     borderRadius: BorderRadius.circular(8),
            //     boxShadow: [
            //       BoxShadow(
            //         color: Colors.grey,
            //         spreadRadius: 5,
            //         blurRadius: 10,
            //         offset: Offset(1, 1),
            //       ),
            //     ],
            //   ),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Text(
            //         widget.description,
            //         style: const TextStyle(
            //           fontSize: 16,
            //           color: Colors.black,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () => _openMapOptions(context),
                  child: Text(
                    'ここへ行く',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFFF407FED),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20.0),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    return FutureBuilder<Map<String, String>>(
      future: _getAddress(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('エラーが発生しました');
        }

        final address = snapshot.data!;
        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: 20, right: 20, left: 20),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Color(0xFFF407FED)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey,
                spreadRadius: 5,
                blurRadius: 10,
                offset: Offset(1, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '〒${address['postalCode']!}',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                ),
              ),
              Text(
                address['address']!,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                ),
              ),
              if (widget.spot_description != null &&
                  widget.spot_description.isNotEmpty) ...[
                const SizedBox(height: 25.0),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: ShapeDecoration(
                    color: Color(0xFFF407FED),
                    shape: Bubble(),
                    shadows: [
                      BoxShadow(
                        color: Color(0xFFF407FED).withOpacity(0.5),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'スポット詳細情報',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 8),
                  child: Html(
                    data: widget.spot_description,
                    style: {
                      "img": Style(
                        display: Display.block,
                      ),
                    },
                    extensions: [
                      ImageExtension(
                        builder: (context) {
                          final attributes = context.attributes;
                          final url = attributes['src'];
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 10),
                            child: url != null
                                ? Image.network(
                              url,
                              errorBuilder: (context, error, stackTrace) {
                                print("Image URL: $url");
                                return Text('Failed to load image');
                              },
                            )
                                : Text('No image URL provided'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceInfo1() {
    if (widget.sourceTitle.isEmpty && widget.sourceLink.isEmpty) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.source_outlined,
              size: 16,
              color: Colors.grey[600],
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.sourceTitle.isNotEmpty)
                    Text(
                      widget.sourceTitle,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (widget.sourceLink.isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(widget.sourceLink);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      child: Text(
                        widget.sourceLink,
                        style: TextStyle(
                          color: Color(0xFF407FED),
                          fontSize: 10.0,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildSourceInfo2() {
    if (widget.subsourceTitle.isEmpty && widget.subsourceLink.isEmpty) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.source_outlined,
              size: 16,
              color: Colors.grey[600],
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.subsourceTitle.isNotEmpty)
                    Text(
                      widget.subsourceTitle,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (widget.subsourceLink.isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(widget.subsourceLink);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      child: Text(
                        widget.subsourceLink,
                        style: TextStyle(
                          color: Color(0xFF407FED),
                          fontSize: 10.0,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
