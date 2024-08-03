import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:parts/spot_page/spot_test.dart';
import 'package:translator/translator.dart';

import 'anime_list_detail_en.dart';

class AnimeListEnPage extends StatefulWidget {
  @override
  _AnimeListEnPageState createState() => _AnimeListEnPageState();
}

class _AnimeListEnPageState extends State<AnimeListEnPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final translator = GoogleTranslator();
  String _searchQuery = '';
  bool _isSearching = false;

  Future<Map<String, Map<String, String>>> _fetchAnimeNamesAndImages() async {
    Map<String, Map<String, String>> animeData = {};
    try {
      QuerySnapshot snapshot = await firestore.collection('locations').get();
      Map<String, QueryDocumentSnapshot> minIdDocs = {};

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>?;
        if (data != null &&
            data.containsKey('animeName') &&
            data.containsKey('imageUrl')) {
          String animeName = data['animeName'];
          if (!minIdDocs.containsKey(animeName) ||
              int.parse(doc.id.split('_').last) <
                  int.parse(minIdDocs[animeName]!.id.split('_').last)) {
            minIdDocs[animeName] = doc;
          }
        }
      }

      for (var entry in minIdDocs.entries) {
        var data = entry.value.data() as Map<String, dynamic>;
        String animeName = data['animeName'];
        String imageUrl = data['imageUrl'];

        // Translate anime name to English
        Translation translation =
            await translator.translate(animeName, to: 'en');
        String translatedAnimeName = translation.text;

        animeData[animeName] = {
          'translatedName': translatedAnimeName,
          'imageUrl': imageUrl
        };
      }
    } catch (e) {
      print("Error fetching and translating anime names and images: $e");
    }
    return animeData;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: _isSearching
              ? AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: TextField(
                    key: ValueKey('searchBar'),
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search anime...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(color: Colors.black),
                  ),
                )
              : Text(
                  'Pilgrimage Spots',
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                  ),
                ),
          leading: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SpotTestScreen()),
              );
            },
            icon: const Icon(
              Icons.check_circle,
              color: Color(0xFF00008b),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: Color(0xFF00008b),
              ),
              onPressed: _toggleSearch,
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                '■ Anime Spot List',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<Map<String, Map<String, String>>>(
                future: _fetchAnimeNamesAndImages(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                        child: Text('No anime names and images found.'));
                  } else {
                    final allAnimeEntries = snapshot.data!.entries.toList();
                    final filteredAnimeEntries = allAnimeEntries
                        .where((entry) => entry.value['translatedName']!
                            .toLowerCase()
                            .contains(_searchQuery))
                        .toList();

                    if (filteredAnimeEntries.isEmpty) {
                      return Center(child: Text('Nothing found.'));
                    }

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.3,
                        mainAxisSpacing: 1.0,
                        crossAxisSpacing: 3.0,
                      ),
                      itemCount: filteredAnimeEntries.length,
                      itemBuilder: (context, index) {
                        final animeNameJa = filteredAnimeEntries[index].key;
                        final animeNameEn = filteredAnimeEntries[index]
                            .value['translatedName']!;
                        final imageUrl =
                            filteredAnimeEntries[index].value['imageUrl']!;
                        return GestureDetector(
                          onTap: () => _navigateToDetails(context, animeNameJa),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final textPainter = TextPainter(
                                text: TextSpan(
                                  text: animeNameEn,
                                  style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold),
                                ),
                                maxLines: 2,
                                textDirection: TextDirection.ltr,
                              )..layout(
                                  maxWidth: constraints.maxWidth -
                                      8.0); // 8.0 はパディング分

                              final textHeight = textPainter.height;
                              final itemHeight = 100 +
                                  textHeight +
                                  12.0; // 画像の高さ + テキストの高さ + パディング

                              return Container(
                                height: itemHeight,
                                padding: const EdgeInsets.all(4.0),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(9.0),
                                      child: SizedBox(
                                        width: 200,
                                        height: 100,
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 4.0),
                                    Expanded(
                                      child: Text(
                                        animeNameEn,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context, String animeNameJa) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeDetailsEnPage(animeName: animeNameJa),
      ),
    );
  }
}
