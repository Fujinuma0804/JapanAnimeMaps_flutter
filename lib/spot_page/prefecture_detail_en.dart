import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:parts/spot_page/anime_list_detail.dart';

import 'anime_list_en_detail.dart';

class PrefectureSpotListEnPage extends StatefulWidget {
  final String prefecture;
  final List<Map<String, dynamic>> locations;
  final String animeName;
  final Map<String, Map<String, double>> prefectureBounds;

  PrefectureSpotListEnPage({
    Key? key,
    required this.prefecture,
    required this.locations,
    required this.animeName,
    required this.prefectureBounds,
  }) : super(key: key);

  @override
  _PrefectureSpotListEnPageState createState() => _PrefectureSpotListEnPageState();
}

class _PrefectureSpotListEnPageState extends State<PrefectureSpotListEnPage> {
  Future<String> getPrefectureImageUrl(String prefectureName) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('prefectures/$prefectureName.jpg');
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting image URL for $prefectureName: $e');
      return '';
    }
  }

  Future<String> getAnimeName(String locationId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('locations')
          .doc(locationId)
          .get();
      return doc.get('animeNameEn') as String? ?? 'Unknown Anime';
    } catch (e) {
      print('Error getting animeName for location $locationId: $e');
      return 'Unknown Anime';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Spot in ${widget.prefecture}',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー画像
          Container(
            height: 200,
            width: double.infinity,
            child: FutureBuilder<String>(
              future: getPrefectureImageUrl(widget.prefecture),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 50,
                    ),
                  );
                } else {
                  return CachedNetworkImage(
                    imageUrl: snapshot.data!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '■ Anime spot in ${widget.prefecture}',
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                mainAxisSpacing: 8.0, // スペースを調整
                crossAxisSpacing: 8.0, // スペースを調整
              ),
              itemCount: widget.locations.length,
              itemBuilder: (context, index) {
                final location = widget.locations[index];
                final locationId = location['locationID'] ?? '';

                return Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('locations')
                                        .doc(locationId)
                                        .get(),
                                    builder: (BuildContext context,
                                        AsyncSnapshot<DocumentSnapshot> snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return Center(
                                            child: CircularProgressIndicator());
                                      }
                                      if (snapshot.hasError) {
                                        return Center(child: Text("An error has occurred"));
                                      }
                                      if (!snapshot.hasData ||
                                          !snapshot.data!.exists) {
                                        return Center(child: Text("Spot not found"));
                                      }

                                      Map<String, dynamic> data = snapshot.data!
                                          .data() as Map<String, dynamic>;
                                      return SpotDetailEnScreen(
                                        titleEn: data['titleEn'] ?? 'Error',
                                        userId: data['userId'] ?? '',
                                        imageUrl: data['imageUrl'] ?? '',
                                        descriptionEn: data['descriptionEn'] ?? '',
                                        spot_description:
                                        data['spot_description'] ?? '',
                                        latitude: (data['latitude'] as num?)
                                            ?.toDouble() ??
                                            0.0,
                                        longitude: (data['longitude'] as num?)
                                            ?.toDouble() ??
                                            0.0,
                                        sourceLink: data['sourceLink'] ?? '',
                                        sourceTitle: data['sourceTitle'] ?? '',
                                        url: data['url'] ?? '',
                                        subMedia: (data['subMedia'] as List?)
                                            ?.where((item) =>
                                        item is Map<String, dynamic>)
                                            .cast<Map<String, dynamic>>()
                                            .toList() ??
                                            [],
                                        locationId: locationId,
                                        animeNameEn:
                                        data['animeNameEn'] ?? 'Unknown Anime',
                                      );
                                    },
                                  ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 120, // 固定の高さを設定
                              width: double.infinity,
                              child: CachedNetworkImage(
                                imageUrl: location['imageUrl'] ?? '',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child:
                                  Icon(Icons.image_not_supported, size: 50),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 4), // 画像とテキストの間隔を調整
                    Container(
                      height: 20, // アニメ名の高さを固定
                      child: FutureBuilder<String>(
                        future: getAnimeName(locationId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Text('Loading...',
                                style: TextStyle(fontSize: 12.0));
                          }
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AnimeDetailsEngPage(
                                    animeNameEn: snapshot.data ?? 'Unknown Anime',
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              snapshot.data ?? 'Unknown Anime',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
