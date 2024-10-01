import 'dart:async';
import 'dart:io' show Platform;

import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

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

  @override
  void initState() {
    super.initState();
    _animeData = _fetchAnimeData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorialTooltip());
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
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

        // 画面のサイズを取得
        final screenSize = MediaQuery.of(context).size;

        // 吹き出しのサイズを定義（おおよその値）
        const tooltipWidth = 200.0;
        const tooltipHeight = 40.0;

        // 吹き出しの位置を計算
        double left = offset.dx - tooltipWidth + size.width;
        double top = offset.dy + size.height + 5.0;

        // 画面右端からはみ出す場合、左に寄せる
        if (left + tooltipWidth > screenSize.width) {
          left = screenSize.width - tooltipWidth - 10.0;
        }

        // 画面下端からはみ出す場合、上に表示する
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

  Future<DocumentSnapshot> _fetchAnimeData() async {
    return await FirebaseFirestore.instance
        .collection('animes')
        .where('name', isEqualTo: widget.animeName)
        .get()
        .then((querySnapshot) {
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first;
      } else {
        throw Exception('Anime not found');
      }
    });
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
        print("Fetched document ID: ${doc.id}");
        print("Fetched document data: $data");
        locations.add({
          'id': doc.id,
          'title': data['title'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'description': data['description'] ?? '',
          'latitude': data['latitude'] ?? 0.0,
          'longitude': data['longitude'] ?? 0.0,
          'sourceTitle': data['sourceTitle'] ?? '',
          'sourceLink': data['sourceLink'] ?? '',
          'url': data['url'] ?? '',
          'subMedia': data['subMedia'] ?? [],
          'userEmail': data['userEmail'] ?? [],
        });
      }
    } catch (e) {
      print("Error fetching locations: $e");
    }
    return locations;
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
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Anime not found'));
          } else {
            Map<String, dynamic> animeData =
                snapshot.data!.data() as Map<String, dynamic>;
            String imageUrl = animeData['imageUrl'] ?? '';
            String userId = animeData['userId'] ?? '';
            return Column(
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/placeholder_image.png',
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          );
                        },
                      )
                    : Image.asset(
                        'assets/placeholder_image.png',
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
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
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                            child: Text(
                                'No locations found for ${widget.animeName}.'));
                      } else {
                        final locations = snapshot.data!;

                        return GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.1,
                            mainAxisSpacing: 10.0,
                            crossAxisSpacing: 10.0,
                          ),
                          itemCount: locations.length,
                          itemBuilder: (context, index) {
                            final location = locations[index];
                            final title = location['title'] as String;
                            final description =
                                location['description'] as String;
                            final imageUrl = location['imageUrl'] as String;
                            final locationId = location['id'] as String;
                            final userEmail =
                                location['userEmail'] as String? ?? '';
                            final userId = userEmail.split('@').first;

                            return GestureDetector(
                              onTap: () {
                                print(
                                    "Navigating to SpotDetailScreen with locationId: $locationId");
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SpotDetailScreen(
                                      title: title,
                                      imageUrl: imageUrl,
                                      description: description,
                                      latitude: location['latitude'] as double,
                                      longitude:
                                          location['longitude'] as double,
                                      sourceLink:
                                          location['sourceLink'] as String,
                                      sourceTitle:
                                          location['sourceTitle'] as String,
                                      url: location['url'] as String,
                                      subMedia: (location['subMedia'] as List)
                                          .where((item) =>
                                              item is Map<String, dynamic>)
                                          .cast<Map<String, dynamic>>()
                                          .toList(),
                                      locationId: locationId,
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
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              width: 200,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Image.asset(
                                                  'assets/placeholder_image.png',
                                                  width: 200,
                                                  height: 100,
                                                  fit: BoxFit.cover,
                                                );
                                              },
                                            )
                                          : Image.asset(
                                              'assets/placeholder_image.png',
                                              width: 200,
                                              height: 100,
                                              fit: BoxFit.cover,
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
                                    const SizedBox(
                                      height: 2.0,
                                    ),
                                    Text(
                                      '投稿者:@'
                                      '$userId',
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
                          },
                        );
                      }
                    },
                  ),
                )
              ],
            );
          }
        },
      ),
    );
  }
}

class SpotDetailScreen extends StatefulWidget {
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String sourceTitle;
  final String sourceLink;
  final String url;
  final List<Map<String, dynamic>> subMedia;
  final String locationId; // 追加：ロケーションID

  const SpotDetailScreen({
    Key? key,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.sourceTitle,
    required this.sourceLink,
    required this.url,
    required this.subMedia,
    required this.locationId,
  }) : super(key: key);

  @override
  _SpotDetailScreenState createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPictureInPicture = false;
  double _pipWidth = 200.0; // PiPのデフォルト幅
  Offset _pipPosition = Offset(16, 16); // PiPのデフォルト位置
  bool _isPipClosed = false; // 新しい変数を追加
  bool _isFavorite = false;

  Future<void> _openMapOptions(BuildContext context) async {
    final googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}";
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
                  } else {
                    throw 'Could not open Google Maps.';
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
                    } else {
                      throw 'Could not open Apple Maps.';
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
            '${place.administrativeArea ?? ''} ${place.locality ?? ''} ${place.street ?? ''}';

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
    }
    for (var subMedia in widget.subMedia) {
      if (subMedia['type'] == 'video') {
        await _initializeVideoPlayer(subMedia['url']);
        break; // 最初の動画のみを初期化
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
        // Revert the state if the operation fails
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
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
      );
      setState(() {});
    } catch (e) {
      print("Error initializing video player: $e");
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locationId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Error',
          ),
        ),
        body: Center(
          child: Text(
            'Error: Invalid location ID',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
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
          )
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollUpdateNotification) {
            if (scrollNotification.metrics.pixels > 0 &&
                !_isPictureInPicture &&
                !_isPipClosed) {
              setState(() {
                _isPictureInPicture = true;
              });
            } else if (scrollNotification.metrics.pixels == 0 &&
                _isPictureInPicture) {
              setState(() {
                _isPictureInPicture = false;
              });
            }
          }
          return true;
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Image.network(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                    ),
                  ),
                  if (_chewieController != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: AspectRatio(
                        aspectRatio: _videoPlayerController!.value.aspectRatio,
                        child: Chewie(controller: _chewieController!),
                      ),
                    )
                  else if (widget.url.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.network(
                        widget.url,
                        fit: BoxFit.cover,
                        height: 200,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey,
                            child: Center(
                              child: Icon(Icons.error, color: Colors.white),
                            ),
                          );
                        },
                      ),
                    )
                  else if (widget.subMedia.isNotEmpty &&
                      (widget.subMedia.first['type'] == 'image' ||
                          widget.subMedia.first['type'] == 'video'))
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: widget.subMedia.first['type'] == 'image'
                          ? Image.network(
                              widget.subMedia.first['url'],
                              fit: BoxFit.cover,
                              height: 200,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.grey,
                                  child: Center(
                                    child:
                                        Icon(Icons.error, color: Colors.white),
                                  ),
                                );
                              },
                            )
                          : AspectRatio(
                              aspectRatio:
                                  _videoPlayerController!.value.aspectRatio,
                              child: Chewie(controller: _chewieController!),
                            ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(widget.latitude, widget.longitude),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('spot_location'),
                            position: LatLng(widget.latitude, widget.longitude),
                          ),
                        },
                      ),
                    ),
                  SizedBox(
                    height: 10.0,
                  ),
                  //以下緯度と経度より郵便番号と住所を取得し表示。
                  //Simulatorでは取得できませんでしたとなるが、実機ではならない。
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: FutureBuilder<Map<String, String>>(
                      future: _getAddress(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text('エラーが発生しました');
                        } else {
                          final address = snapshot.data!;
                          return SizedBox(
                            width: double.infinity,
                            child: Card(
                              color: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '〒${address['postalCode']!}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      address['address']!,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: () => _openMapOptions(context),
                        child: Text('ここへ行く'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Color(0xFF00008b),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sourceTitle,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10.0,
                          ),
                        ),
                        Text(
                          widget.sourceLink,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 20.0,
                  ),
                ],
              ),
            ),
            if (_isPictureInPicture &&
                _chewieController != null &&
                _videoPlayerController != null &&
                !_isPipClosed) // 条件を修正
              Positioned(
                left: _pipPosition.dx,
                top: _pipPosition.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _pipPosition += details.delta;
                    });
                  },
                  child: Stack(
                    children: [
                      SizedBox(
                        width: _pipWidth,
                        height: _pipWidth /
                            _videoPlayerController!.value.aspectRatio,
                        child: Chewie(controller: _chewieController!),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.fullscreen, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _isPictureInPicture = false;
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _isPictureInPicture = false;
                                  _isPipClosed = true; // PiPが閉じられたことを記録
                                  _videoPlayerController?.pause();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _pipWidth = (_pipWidth - details.delta.dx)
                                  .clamp(100.0, 300.0);
                            });
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            color: Colors.transparent,
                            child: Icon(Icons.drag_handle,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
