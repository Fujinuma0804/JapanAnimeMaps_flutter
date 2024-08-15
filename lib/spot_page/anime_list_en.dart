import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:parts/spot_page/check_in_en.dart';
import 'package:translator/translator.dart'; // google_translateの代わりにtranslatorパッケージを利用

import 'anime_list_detail.dart';
import 'customer_anime_request.dart';
import 'liked_post.dart';

class AnimeListEnPage extends StatefulWidget {
  @override
  _AnimeListEnPageState createState() => _AnimeListEnPageState();
}

class _AnimeListEnPageState extends State<AnimeListEnPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final GoogleTranslator translator = GoogleTranslator(); // インスタンス化
  String _searchQuery = '';
  bool _isSearching = false;
  List<Map<String, dynamic>> _allAnimeData = [];

  @override
  void initState() {
    super.initState();
    _fetchAnimeData();
  }

  Future<void> _fetchAnimeData() async {
    try {
      QuerySnapshot animeSnapshot = await firestore.collection('animes').get();
      _allAnimeData = await Future.wait(animeSnapshot.docs.map((doc) async {
        var data = doc.data() as Map<String, dynamic>;
        Translation translatedName = await translator.translate(
          data['name'] ?? '',
          from: 'ja',
          to: 'en',
        );
        return {
          'name': translatedName.text,
          'imageUrl': data['imageUrl'] ?? '',
        };
      }).toList());
      setState(() {});
    } catch (e) {
      print("Error fetching anime data: $e");
    }
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
    List<Map<String, dynamic>> filteredAnimeData = _allAnimeData
        .where((anime) => anime['name'].toLowerCase().contains(_searchQuery))
        .toList();

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search anime...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: Colors.black),
                )
              : Text(
                  'Spots',
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                  ),
                ),
          actions: [
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SpotTestScreenEn()),
              ),
              icon: const Icon(Icons.check_circle, color: Color(0xFF00008b)),
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => FavoriteLocationsPage()),
              ),
              icon: const Icon(Icons.favorite, color: Color(0xFF00008b)),
            ),
            IconButton(
              icon: Icon(
                Icons.add,
                color: Color(0xFF00008b),
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AnimeRequestCustomerForm()));
              },
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
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                '■ Anime List',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: _allAnimeData.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : filteredAnimeData.isEmpty
                      ? Center(child: Text('Nothing found.'))
                      : GridView.builder(
                          padding: EdgeInsets.only(bottom: 16.0),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.3,
                            mainAxisSpacing: 1.0,
                            crossAxisSpacing: 3.0,
                          ),
                          itemCount: filteredAnimeData.length,
                          itemBuilder: (context, index) {
                            final animeName = filteredAnimeData[index]['name'];
                            final imageUrl =
                                filteredAnimeData[index]['imageUrl'];
                            return GestureDetector(
                              onTap: () =>
                                  _navigateToDetails(context, animeName),
                              child: AnimeGridItem(
                                  animeName: animeName, imageUrl: imageUrl),
                            );
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
        builder: (context) => AnimeDetailsPage(animeName: animeName),
      ),
    );
  }
}

class AnimeGridItem extends StatelessWidget {
  final String animeName;
  final String imageUrl;

  const AnimeGridItem(
      {Key? key, required this.animeName, required this.imageUrl})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: animeName,
            style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
          ),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final textHeight = textPainter.height;
        final itemHeight = 100 + textHeight + 12.0;

        return Container(
          height: itemHeight,
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9.0),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 200,
                  height: 100,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Icon(Icons.error),
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
    );
  }
}
