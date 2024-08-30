import 'dart:io' show Platform;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:translator/translator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class AnimeDetailsEnPage extends StatefulWidget {
  final String animeName;

  AnimeDetailsEnPage({required this.animeName});

  @override
  _AnimeDetailsEnPageState createState() => _AnimeDetailsEnPageState();
}

class _AnimeDetailsEnPageState extends State<AnimeDetailsEnPage> {
  final translator = GoogleTranslator();
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;
  String? _translatedAnimeName;

  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scaleFactor =
        screenWidth / 375; // 375 is used as a base width (iPhone 6/7/8)
    return baseSize *
        scaleFactor.clamp(0.8, 1.2); // Limit scaling between 80% and 120%
  }

  @override
  void initState() {
    super.initState();
    _fetchLocationsAndTranslate();
  }

  Future<void> _fetchLocationsAndTranslate() async {
    setState(() => _isLoading = true);

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .where('animeName', isEqualTo: widget.animeName)
          .get();

      List<Map<String, dynamic>> locations = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'description': data['description'] ?? '',
          'latitude': data['latitude'] ?? 0.0,
          'longitude': data['longitude'] ?? 0.0,
          'sourceTitle': data['sourceTitle'] ?? '',
          'sourceLink': data['sourceLink'] ?? '',
          'url': data['url'] ?? '',
          'subMedia': (data['subMedia'] as List<dynamic>?)
                  ?.where((item) => item is Map<String, dynamic>)
                  .cast<Map<String, dynamic>>()
                  .toList() ??
              [],
        };
      }).toList();

      // Translate anime name
      _translatedAnimeName = await translateToEnglish(widget.animeName);

      // Translate location titles in parallel
      await Future.wait(locations.map((location) async {
        location['translatedTitle'] =
            await translateToEnglish(location['title']);
      }));

      setState(() {
        _locations = locations;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching locations: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<String> translateToEnglish(String text) async {
    try {
      var translation = await translator.translate(text, to: 'en');
      return translation.text;
    } catch (e) {
      print('Translation error: $e');
      return text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _translatedAnimeName ?? widget.animeName,
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
            fontSize: _getResponsiveFontSize(context, 18),
          ),
          maxLines: 2, // 2行まで表示を許可
          overflow: TextOverflow.ellipsis, // 2行を超える場合は省略
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _locations.isEmpty
              ? Center(
                  child: Text(
                  'No locations found for ${widget.animeName}.',
                  style:
                      TextStyle(fontSize: _getResponsiveFontSize(context, 16)),
                ))
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.3,
                    mainAxisSpacing: 10.0,
                    crossAxisSpacing: 10.0,
                  ),
                  itemCount: _locations.length,
                  itemBuilder: (context, index) {
                    final location = _locations[index];
                    return GestureDetector(
                      onTap: () => _navigateToDetails(context, location),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9.0),
                              child: CachedNetworkImage(
                                imageUrl: location['imageUrl'],
                                width: 200,
                                height: 100,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[300],
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) =>
                                    Image.asset(
                                  'assets/placeholder_image.png',
                                  width: 200,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            SizedBox(height: 5.0),
                            Text(
                              location['translatedTitle'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 10),
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _navigateToDetails(BuildContext context, Map<String, dynamic> location) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpotDetailEnScreen(
          title: location['translatedTitle'],
          imageUrl: location['imageUrl'],
          description: location['description'],
          latitude: location['latitude'],
          longitude: location['longitude'],
          sourceLink: location['sourceLink'],
          sourceTitle: location['sourceTitle'],
          url: location['url'],
          subMedia: location['subMedia'] as List<Map<String, dynamic>>,
          locationId: location['id'],
        ),
      ),
    );
  }
}

class SpotDetailEnScreen extends StatefulWidget {
  final String title;
  final String description;
  final double? latitude;
  final double? longitude;
  final String imageUrl;
  final String sourceTitle;
  final String sourceLink;
  final String url;
  final List<Map<String, dynamic>> subMedia;
  final String locationId;

  const SpotDetailEnScreen({
    Key? key,
    required this.title,
    required this.description,
    this.latitude,
    this.longitude,
    required this.imageUrl,
    required this.sourceTitle,
    required this.sourceLink,
    required this.url,
    required this.subMedia,
    required this.locationId,
  }) : super(key: key);

  @override
  _SpotDetailEnScreenState createState() => _SpotDetailEnScreenState();
}

class _SpotDetailEnScreenState extends State<SpotDetailEnScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPictureInPicture = false;
  double _pipWidth = 200.0;
  Offset _pipPosition = Offset(16, 16);
  bool _isPipClosed = false; // 新しい変数を追加
  bool _isFavorite = false;
  final translator = GoogleTranslator();

  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scaleFactor =
        screenWidth / 375; // 375 is used as a base width (iPhone 6/7/8)
    return baseSize *
        scaleFactor.clamp(0.8, 1.2); // Limit scaling between 80% and 120%
  }

  Future<String> translateToEnglish(String text) async {
    try {
      var translation = await translator.translate(text, to: 'en');
      return translation.text;
    } catch (e) {
      print('Translation error: $e');
      return text;
    }
  }

  Future<Map<String, String>> _getAddress() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.latitude!,
        widget.longitude!,
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
      'postalCode': 'Not available',
      'address': 'Not available',
    };
  }

  Future<void> _openMapOptions(BuildContext context) async {
    if (widget.latitude == null || widget.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location data not available')),
      );
      return;
    }
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
        break;
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
        await favoriteRef.set({
          'locationId': widget.locationId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
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
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
      _chewieController = null;
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
        title: FutureBuilder<String>(
          future: translateToEnglish('Details'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text('Translating...',
                  style:
                      TextStyle(fontSize: _getResponsiveFontSize(context, 18)));
            }
            return Text(
              snapshot.data ?? 'Details',
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
                fontSize: _getResponsiveFontSize(context, 20),
              ),
            );
          },
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
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 24),
                        fontWeight: FontWeight.bold,
                      ),
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
                      child: widget.latitude != null && widget.longitude != null
                          ? GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target:
                                    LatLng(widget.latitude!, widget.longitude!),
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('spot_location'),
                                  position: LatLng(
                                      widget.latitude!, widget.longitude!),
                                ),
                              },
                            )
                          : Center(child: Text('Location data not available')),
                    ),
                  SizedBox(
                    height: 10.0,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: FutureBuilder<Map<String, String>>(
                      future: _getAddress(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text('An error occurred');
                        } else {
                          final address = snapshot.data!;
                          return FutureBuilder<String>(
                            future: translateToEnglish(
                                '${address['postalCode']!}\n${address['address']!}'),
                            builder: (context, translationSnapshot) {
                              if (translationSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return CircularProgressIndicator();
                              }
                              final translatedAddress =
                                  translationSnapshot.data ?? '';
                              final addressParts =
                                  translatedAddress.split('\n');
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          addressParts[0], // Postal code
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          addressParts.length > 1
                                              ? addressParts[1]
                                              : 'Address not available',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          maxLines: 3, // 3行まで表示を許可
                                          overflow: TextOverflow
                                              .ellipsis, // 3行を超える場合は省略
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
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
                        child: Text('Go To here'),
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
                      widget.title,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 24),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 3, // 3行まで表示を許可
                      overflow: TextOverflow.ellipsis, // 3行を超える場合は省略
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
                            fontSize: _getResponsiveFontSize(context, 10),
                          ),
                          maxLines: 2, // 2行まで表示を許可
                          overflow: TextOverflow.ellipsis, // 2行を超える場合は省略
                        ),
                        Text(
                          widget.sourceLink,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: _getResponsiveFontSize(context, 10),
                          ),
                          maxLines: 2, // 2行まで表示を許可
                          overflow: TextOverflow.ellipsis, // 2行を超える場合は省略
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
