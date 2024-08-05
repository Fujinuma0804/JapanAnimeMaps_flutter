import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
          'title': data['title'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'description': data['description'] ?? '',
          'latitude': data['latitude'] ?? 0.0,
          'longitude': data['longitude'] ?? 0.0,
          'sourceTitle': data['sourceTitle'] ?? '',
          'sourceLink': data['sourceLink'] ?? '',
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
                          child: Image.network(
                            imageUrl,
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

class SpotDetailScreen extends StatelessWidget {
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String sourceTitle;
  final String sourceLink;

  const SpotDetailScreen({
    Key? key,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.sourceTitle,
    required this.sourceLink,
  }) : super(key: key);

  Future<void> _openMapOptions(BuildContext context) async {
    final googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude";
    final appleMapsUrl = "http://maps.apple.com/?q=$latitude,$longitude";

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
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            if (imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                ),
              ),
            Align(
              alignment: FractionalOffset.centerRight,
              child: Text(
                sourceTitle,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10.0,
                ),
              ),
            ),
            Align(
              alignment: FractionalOffset.centerRight,
              child: Text(
                sourceLink,
                style: TextStyle(
                  fontSize: 10.0,
                  color: Colors.grey,
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(latitude, longitude),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('spot_location'),
                    position: LatLng(latitude, longitude),
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
                description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
