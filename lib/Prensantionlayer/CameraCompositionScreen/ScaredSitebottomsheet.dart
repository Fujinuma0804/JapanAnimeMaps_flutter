import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:parts/Dataprovider/model/sacred_site_model.dart';
import 'package:geocoding/geocoding.dart';

class SacredSiteBottomSheet extends StatefulWidget {
  final SacredSite? selectedSacredSite;

  const SacredSiteBottomSheet({
    Key? key,
    required this.selectedSacredSite,
  }) : super(key: key);

  @override
  _SacredSiteBottomSheetState createState() => _SacredSiteBottomSheetState();
}

class _SacredSiteBottomSheetState extends State<SacredSiteBottomSheet> {
  List<SacredSite> _sacredSites = [];
  bool _isLoadingSacredSites = false;
  bool _hasLoadedSacredSites = false;

  final int _pageSize = 30;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreSacredSites = true;
  bool _isLoadingMoreSacredSites = false;

  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadSacredSitesFromFirebase();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMoreSacredSites();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSacredSitesFromFirebase({bool loadMore = false}) async {
    try {
      if (!mounted) return;

      if (!loadMore) {
        setState(() {
          _isLoadingSacredSites = true;
          _hasMoreSacredSites = true;
          _lastDocument = null;
        });
      } else {
        if (!_hasMoreSacredSites || _isLoadingMoreSacredSites) return;
        setState(() {
          _isLoadingMoreSacredSites = true;
        });
      }

      Query query = _firestore
          .collection('locations')
          .orderBy('locationID')
          .limit(_pageSize);

      if (loadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      QuerySnapshot querySnapshot = await query.get();

      List<SacredSite> sites = [];
      List<DocumentSnapshot> newDocuments = [];

      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          String _getStringValue(dynamic value) {
            if (value == null) return '';
            if (value is String) return value;
            if (value is List<dynamic>) {
              if (value.isNotEmpty) return value.first.toString();
              return '';
            }
            return value.toString();
          }

          double _getDoubleValue(dynamic value) {
            if (value == null) return 0.0;
            if (value is double) return value;
            if (value is int) return value.toDouble();
            if (value is String) return double.tryParse(value) ?? 0.0;
            return 0.0;
          }

          int _getIntValue(dynamic value) {
            if (value == null) return 0;
            if (value is int) return value;
            if (value is double) return value.round();
            if (value is String) return int.tryParse(value) ?? 0;
            return 0;
          }

          SacredSite site = SacredSite(
            id: doc.id,
            imageUrl: _getStringValue(data['imageUrl']),
            locationID: _getStringValue(data['locationID']),
            latitude: _getDoubleValue(data['latitude']),
            longitude: _getDoubleValue(data['longitude']),
            point: _getIntValue(data['point']),
            sourceLink: _getStringValue(data['sourceLink']),
            sourceTitle: _getStringValue(data['sourceTitle']),
            subMedia: _getStringValue(data['subMedia']),
          );

          if (site.imageUrl.isNotEmpty) {
            sites.add(site);
            newDocuments.add(doc);
          }
        } catch (e) {
          print('Error parsing document ${doc.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          if (loadMore) {
            _sacredSites.addAll(sites);
            _isLoadingMoreSacredSites = false;
          } else {
            _sacredSites = sites;
            _isLoadingSacredSites = false;
            _hasLoadedSacredSites = true;
          }

          _hasMoreSacredSites = sites.length == _pageSize;
          if (newDocuments.isNotEmpty) {
            _lastDocument = newDocuments.last;
          }
        });
      }
    } catch (e) {
      print('Error loading sacred sites from Firebase: $e');
      if (mounted) {
        setState(() {
          _isLoadingSacredSites = false;
          _isLoadingMoreSacredSites = false;
          _hasLoadedSacredSites = !loadMore ? false : _hasLoadedSacredSites;
        });
      }
    }
  }

  void _loadMoreSacredSites() {
    if (_hasMoreSacredSites && !_isLoadingMoreSacredSites) {
      _loadSacredSitesFromFirebase(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.photo_library,
                        color: Color(0xFF00008b), size: 24),
                    SizedBox(width: 8),
                    Text(
                      '聖なる画像を選択',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.grey, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildFirebaseSacredSiteGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildFirebaseSacredSiteGrid() {
    if (_isLoadingSacredSites && !_isLoadingMoreSacredSites) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 16),
            Text(
              '聖地を読み込んでいます...',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasLoadedSacredSites) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(Icons.photo_library, size: 40, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              '聖地画像を読み込み',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Firebaseから聖地データを取得します',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadSacredSitesFromFirebase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '聖地を読み込む',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_sacredSites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(Icons.search_off, size: 40, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              '聖地が見つかりません',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'インターネット接続を確認してください',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 16 / 14,
            ),
            itemCount: _sacredSites.length + (_hasMoreSacredSites ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _sacredSites.length) {
                return _buildLoadingIndicator();
              }
              final site = _sacredSites[index];
              return _buildFirebaseSacredSiteItem(site);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return _isLoadingMoreSacredSites
        ? Card(
            color: Colors.grey[50],
            elevation: 2,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '読み込み中...',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          )
        : SizedBox.shrink();
  }

  Widget _buildFirebaseSacredSiteItem(SacredSite site) {
    return GestureDetector(
      onTap: () {
        // FIXED: Directly return the selected site
        Navigator.of(context).pop(site);
      },
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: widget.selectedSacredSite?.id == site.id
                ? Border.all(color: Colors.blue, width: 2)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: CachedNetworkImage(
                      imageUrl: site.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(
                            Icons.photo,
                            size: 32,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 32,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Error',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.sourceTitle.isNotEmpty ? site.sourceTitle : '聖地',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 12, color: Colors.red),
                            SizedBox(width: 4),
                            FutureBuilder<List<Placemark>>(
                              future: placemarkFromCoordinates(
                                  site.latitude, site.longitude),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Expanded(
                                    child: Text(
                                      'Loading...',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }

                                if (snapshot.hasError ||
                                    snapshot.data == null ||
                                    snapshot.data!.isEmpty) {
                                  return Expanded(
                                    child: Text(
                                      'Unknown Location',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }

                                final placemark = snapshot.data!.first;
                                final locationName = placemark.locality ??
                                    placemark.subAdministrativeArea ??
                                    placemark.administrativeArea ??
                                    'Unknown Location';

                                return Expanded(
                                  child: Text(
                                    locationName,
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.selectedSacredSite?.id == site.id)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
