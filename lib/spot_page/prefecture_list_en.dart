import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:parts/spot_page/anime_list_en_ranking.dart';
import 'package:parts/spot_page/prefecture_detail_en.dart';

class PrefectureListEnPage extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> prefectureSpots;
  final String searchQuery;
  final Function onFetchPrefectureData;

  const PrefectureListEnPage({
    Key? key,
    required this.prefectureSpots,
    required this.searchQuery,
    required this.onFetchPrefectureData,
  }) : super(key: key);

  @override
  _PrefectureListEnPageState createState() => _PrefectureListEnPageState();
}

class _PrefectureListEnPageState extends State<PrefectureListEnPage> {
  final FirebaseStorage storage = FirebaseStorage.instance;
  final Map<String, List<String>> regionsEn = {
    'Tohoku': ['Hokaido', 'Aomori', 'Iwate', 'Miyagi', 'Akita', 'Yamagata', 'Fukushima'],
    'Kanto': ['Ibaraki', 'Tochigi', 'Gunma', 'Saitama', 'Chiba', 'Tokyo', 'Kanagawa'],
    'Chubu': ['Nigata', 'Toyama', 'Ishikawa', 'Fukui', 'Yamanashi', 'Nagano', 'Gihu', 'Shizuoka', 'Aichi'],
    'Kinki': ['Mie', 'Shiga', 'Kyoto', 'Osaka', 'Hyogo', 'Nara', 'Wakayama'],
    'Chugoku・Shikoku': ['Tottori', 'Shimane', 'Okayama', 'Hiroshima', 'Yamaguchi', 'Tokushima', 'Kagawa', 'Ehime', 'Kochi'],
    'Kyusyu': ['Fukuoka', 'Saga', 'Nagasaki', 'Kumamoto', 'Oita', 'Miyazaki', 'Kagoshima', 'Okinawa'],
  };

  Set<String> selectedPrefectures = {};
  String currentRegion = '';

  @override
  void initState() {
    super.initState();
    widget.onFetchPrefectureData();
  }

  Future<String> getPrefectureImageUrl(String prefectureName) async {
    try {
      final ref = storage.ref().child('prefectures/$prefectureName.jpg');
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting image URL for $prefectureName: $e');
      return '';
    }
  }

  List<String> getFilteredPrefectures() {
    return widget.prefectureSpots.keys.where((prefecture) {
      bool matchesSearch =
          prefecture.toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
              (widget.prefectureSpots[prefecture]?.any((spot) {
                bool animeMatch = spot['anime']
                    ?.toString()
                    .toLowerCase()
                    .contains(widget.searchQuery.toLowerCase()) ??
                    false;
                bool nameMatch = spot['name']
                    ?.toString()
                    .toLowerCase()
                    .contains(widget.searchQuery.toLowerCase()) ??
                    false;
                return animeMatch || nameMatch;
              }) ??
                  false);

      bool matchesRegion = selectedPrefectures.isEmpty ||
          selectedPrefectures.contains(prefecture);

      return matchesSearch && matchesRegion;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    List<String> filteredPrefectures = getFilteredPrefectures();

    for (String prefecture in filteredPrefectures) {
      List<Map<String, dynamic>> spots =
          widget.prefectureSpots[prefecture] ?? [];
      print('Debug: $prefecture のスポット数: ${spots.length}');
      for (var spot in spots) {
        print(
            'Debug: $prefecture のスポット: ${spot['name'] ?? 'タイトルなし'}, LocationID: ${spot['locationID'] ?? 'ID未設定'}');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            '■ List of prefectures',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Container(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: regionsEn.keys.map((region) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    hint: Text(
                      region,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00008b),
                      ),
                    ),
                    icon: Icon(Icons.arrow_drop_down, color: Color(0xFF00008b)),
                    items: regionsEn[region]!.map((String prefecture) {
                      return DropdownMenuItem<String>(
                        value: prefecture,
                        child: Text(prefecture),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          if (selectedPrefectures.contains(newValue)) {
                            selectedPrefectures.remove(newValue);
                          } else {
                            selectedPrefectures.add(newValue);
                          }
                          currentRegion = region;
                        });
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Container(
          padding: EdgeInsets.all(8.0),
          color: Color(0xFFE6E6FA),
          child: Row(
            children: [
              Icon(Icons.place, color: Color(0xFF00008b)),
              SizedBox(width: 8),
              Text(
                'Currently selected region: $currentRegion',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Selected prefecture: ${selectedPrefectures.isEmpty ? "Nothing" : selectedPrefectures.join(", ")}',
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedPrefectures.clear();
                    currentRegion = '';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00008b),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                ),
                child: Text(
                  'clear',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.prefectureSpots.isEmpty
              ? Center(child: CircularProgressIndicator())
              : GridView.builder(
            padding: EdgeInsets.all(16.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: filteredPrefectures.length,
            itemBuilder: (context, index) {
              final prefecture = filteredPrefectures[index];
              final spotCount =
                  widget.prefectureSpots[prefecture]?.length ?? 0;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PrefectureSpotListEnPage(
                        prefecture: prefecture,
                        locations:
                        widget.prefectureSpots[prefecture] ?? [],
                        animeName: '',
                        prefectureBounds: {},
                      ),
                    ),
                  );
                },
                child: PrefectureGridItem(
                  prefectureName: prefecture,
                  spotCount: spotCount,
                  getImageUrl: getPrefectureImageUrl,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// PrefectureGridItem, PrefectureSpotListPage クラスは変更なし

class PrefectureGridItem extends StatelessWidget {
  final String prefectureName;
  final int spotCount;
  final Future<String> Function(String) getImageUrl;

  const PrefectureGridItem({
    Key? key,
    required this.prefectureName,
    required this.spotCount,
    required this.getImageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: FutureBuilder<String>(
              future: getImageUrl(prefectureName),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.image_not_supported, size: 50),
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
            padding: EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(
                  prefectureName,
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Number of spots: $spotCount',
                  style: TextStyle(
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}