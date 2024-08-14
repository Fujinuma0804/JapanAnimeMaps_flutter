import 'dart:io' show Platform;

import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuthをインポート
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class AnimeDetailsPage extends StatelessWidget {
  final String animeName;

  AnimeDetailsPage({required this.animeName});

  Future<List<Map<String, dynamic>>> _fetchLocationsForAnime() async {
    List<Map<String, dynamic>> locations = [];
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .where('animeName', isEqualTo: animeName)
          .get();

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        locations.add({
          'id': doc.id, // ドキュメントIDを追加
          'title': data['title'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'description': data['description'] ?? '',
          'latitude': data['latitude'] ?? 0.0,
          'longitude': data['longitude'] ?? 0.0,
          'sourceTitle': data['sourceTitle'] ?? '',
          'sourceLink': data['sourceLink'] ?? '',
          'url': data['url'] ?? '',
          'subMedia': data['subMedia'] ?? [],
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
          animeName,
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchLocationsForAnime(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No locations found for $animeName.'));
          } else {
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
                final title = location['title'] as String;
                final description = location['description'] as String;
                final imageUrl = location['imageUrl'] as String;
                final locationId = location['id'] as String; // ドキュメントIDを取得

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SpotDetailScreen(
                          title: title,
                          imageUrl: imageUrl,
                          description: description,
                          latitude: location['latitude'] as double,
                          longitude: location['longitude'] as double,
                          sourceLink: location['sourceLink'] as String,
                          sourceTitle: location['sourceTitle'] as String,
                          url: location['url'] as String,
                          subMedia: (location['subMedia'] as List)
                              .where((item) => item is Map<String, dynamic>)
                              .cast<Map<String, dynamic>>()
                              .toList(),
                          locationId: locationId, // locationIdを渡す
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
                                  errorBuilder: (context, error, stackTrace) {
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
                        SizedBox(height: 8.0),
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
                      ],
                    ),
                  ),
                );
              },
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
    required this.locationId, // 追加：ロケーションID
  }) : super(key: key);

  @override
  _SpotDetailScreenState createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPictureInPicture = false;
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
    if (user != null) {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(widget.locationId)
          .get();

      setState(() {
        _isFavorite = docSnapshot.exists;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final favoriteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(widget.locationId);

      setState(() {
        _isFavorite = !_isFavorite;
      });

      if (_isFavorite) {
        // お気に入りに追加
        await favoriteRef.set({
          'locationId': widget.locationId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // お気に入りから削除
        await favoriteRef.delete();
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
            if (scrollNotification.metrics.pixels > 0 && !_isPictureInPicture) {
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
            if (_isPictureInPicture && _chewieController != null)
              Positioned(
                right: 16,
                bottom: 16,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isPictureInPicture = false;
                    });
                  },
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: MediaQuery.of(context).size.width *
                        0.8 /
                        _videoPlayerController!.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
