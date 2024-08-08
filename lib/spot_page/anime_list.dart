import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:parts/spot_page/spot_test.dart';

import 'anime_list_detail.dart';
import 'liked_post.dart';

class AnimeListPage extends StatefulWidget {
  @override
  _AnimeListPageState createState() => _AnimeListPageState();
}

class _AnimeListPageState extends State<AnimeListPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  Future<Map<String, String>> _fetchAnimeNamesAndImages() async {
    Map<String, String> animeData = {};
    try {
      QuerySnapshot snapshot = await firestore.collection('locations').get();
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('animeName')) {
          String animeName = data['animeName'];
          animeData[animeName] = await _fetchImageUrl(animeName);
        }
      }
    } catch (e) {
      print("Error fetching anime names and images: $e");
    }
    return animeData;
  }

  Future<String> _fetchImageUrl(String animeName) async {
    try {
      QuerySnapshot snapshot = await firestore
          .collection('animes')
          .where('name', isEqualTo: animeName)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('imageUrl')) {
          return data['imageUrl'];
        }
      }
    } catch (e) {
      print("Error fetching image URL for $animeName: $e");
    }
    return '';
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
                      hintText: 'アニメで検索...',
                      hintStyle:
                          TextStyle(color: Colors.grey), // Placeholder color
                      border: InputBorder.none,
                    ),
                    style: TextStyle(color: Colors.black), // Text color
                  ),
                )
              : Text(
                  '巡礼スポット',
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                  ),
                ),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SpotTestScreen()),
                );
              },
              icon: const Icon(
                Icons.check_circle,
                color: Color(0xFF00008b),
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => FavoriteLocationsPage()),
                );
              },
              icon: const Icon(
                Icons.favorite,
                color: Color(0xFF00008b),
              ),
            ),
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
              padding: EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 8.0), // 上下のパディングも追加
              child: Text(
                '■ アニメスポット一覧',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<Map<String, String>>(
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
                        .where((entry) =>
                            entry.key.toLowerCase().contains(_searchQuery))
                        .toList();

                    if (filteredAnimeEntries.isEmpty) {
                      return Center(child: Text('何も見つかりませんでした。。'));
                    }

                    return GridView.builder(
                      padding: EdgeInsets.only(bottom: 16.0),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.3,
                        mainAxisSpacing: 1.0,
                        crossAxisSpacing: 3.0,
                      ),
                      itemCount: filteredAnimeEntries.length,
                      itemBuilder: (context, index) {
                        final animeName = filteredAnimeEntries[index].key;
                        final imageUrl = filteredAnimeEntries[index].value;
                        return GestureDetector(
                          onTap: () => _navigateToDetails(context, animeName),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // テキストの高さを計算
                              final textPainter = TextPainter(
                                text: TextSpan(
                                  text: animeName,
                                  style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold),
                                ),
                                maxLines: 2,
                                textDirection: TextDirection.ltr,
                              )..layout(maxWidth: constraints.maxWidth);

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
                                        animeName,
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

  void _navigateToDetails(BuildContext context, String animeName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeDetailsPage(
          animeName: animeName,
        ),
      ),
    );
  }
}
