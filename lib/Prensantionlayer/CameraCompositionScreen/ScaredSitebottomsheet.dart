// Separate Stateful Widget for the Bottom Sheet to manage its own state
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:parts/Prensantionlayer/CameraCompositionScreen/Capturevideo_image.dart';

class SacredSiteBottomSheet extends StatefulWidget {
  final SacredSite? selectedSacredSite;
  final Function(SacredSite) onSacredSiteSelected;

  const SacredSiteBottomSheet({
    Key? key,
    required this.selectedSacredSite,
    required this.onSacredSiteSelected,
  }) : super(key: key);

  @override
  _SacredSiteBottomSheetState createState() => _SacredSiteBottomSheetState();
}

class _SacredSiteBottomSheetState extends State<SacredSiteBottomSheet> {
  // Firebase Sacred Sites - now managed only in bottom sheet
  List<SacredSite> _sacredSites = [];
  bool _isLoadingSacredSites = false;
  bool _hasLoadedSacredSites = false;

  // Pagination variables
  final int _pageSize = 30; // Number of documents per page
  DocumentSnapshot? _lastDocument; // Last document for pagination
  bool _hasMoreSacredSites = true; // Whether there are more documents to load
  bool _isLoadingMoreSacredSites = false; // Loading state for pagination

  // Scroll controller for detecting when to load more
  final ScrollController _scrollController = ScrollController();

  // Firebase instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add this for loading state management
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier<bool>(false);
  String? _currentlyLoadingId;

  @override
  void initState() {
    super.initState();
    // Always load Firebase data when bottom sheet is created
    _loadSacredSitesFromFirebase();

    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(SacredSiteBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No need to check tabs since we only show Firebase data
  }

  // Scroll listener for pagination
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMoreSacredSites();
    }
  }

  // Preload images for faster display
  void _preloadImages() {
    if (_sacredSites.isNotEmpty) {
      // Preload all images in background
      for (final site in _sacredSites) {
        precacheImage(
            CachedNetworkImageProvider(
              site.imageUrl,
            ),
            context);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _loadingNotifier.dispose();
    super.dispose();
  }

  // Load sacred sites from Firebase with pagination
  Future<void> _loadSacredSitesFromFirebase({bool loadMore = false}) async {
    try {
      if (!mounted) return;

      // If not loading more, reset the state
      if (!loadMore) {
        setState(() {
          _isLoadingSacredSites = true;
          _hasMoreSacredSites = true;
          _lastDocument = null;
        });
      } else {
        // If loading more and no more documents or already loading, return
        if (!_hasMoreSacredSites || _isLoadingMoreSacredSites) return;

        setState(() {
          _isLoadingMoreSacredSites = true;
        });
      }

      Query query = _firestore
          .collection('locations')
          .orderBy('locationID') // Order by a field for consistent pagination
          .limit(_pageSize); // Limit results per page

      // If loading more, start after the last document
      if (loadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      QuerySnapshot querySnapshot = await query.get();

      List<SacredSite> sites = [];
      List<DocumentSnapshot> newDocuments = [];

      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          // Helper function to safely extract string values
          String _getStringValue(dynamic value) {
            if (value == null) return '';
            if (value is String) return value;
            if (value is List<dynamic>) {
              if (value.isNotEmpty) {
                return value.first.toString();
              }
              return '';
            }
            return value.toString();
          }

          // Helper function to safely extract numeric values
          double _getDoubleValue(dynamic value) {
            if (value == null) return 0.0;
            if (value is double) return value;
            if (value is int) return value.toDouble();
            if (value is String) {
              return double.tryParse(value) ?? 0.0;
            }
            return 0.0;
          }

          int _getIntValue(dynamic value) {
            if (value == null) return 0;
            if (value is int) return value;
            if (value is double) return value.round();
            if (value is String) {
              return int.tryParse(value) ?? 0;
            }
            return 0;
          }

          // Create SacredSite object from document data with safe parsing
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

          // Only add sites that have valid image URLs
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
            // Append new sites for infinite scroll
            _sacredSites.addAll(sites);
            _isLoadingMoreSacredSites = false;
          } else {
            // Replace sites for initial load
            _sacredSites = sites;
            _isLoadingSacredSites = false;
            _hasLoadedSacredSites = true;
          }

          // Update pagination state
          _hasMoreSacredSites = sites.length == _pageSize;
          if (newDocuments.isNotEmpty) {
            _lastDocument = newDocuments.last;
          }
        });

        // Preload images after sacred sites are loaded
        if (!loadMore) {
          _preloadImages();
        }
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

  // Method to load more data (call this when user scrolls to bottom)
  void _loadMoreSacredSites() {
    if (_hasMoreSacredSites && !_isLoadingMoreSacredSites) {
      _loadSacredSitesFromFirebase(loadMore: true);
    }
  }

  // Build loading indicator for pagination
  Widget _buildLoadingIndicator() {
    return _isLoadingMoreSacredSites
        ? Container(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          )
        : SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header with Tabs
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '聖なる画像を選択',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 24),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
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
    // Show loading state
    if (_isLoadingSacredSites && !_isLoadingMoreSacredSites) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              '聖地を読み込んでいます...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Show empty state or load button
    if (!_hasLoadedSacredSites) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_download, color: Colors.white54, size: 64),
            SizedBox(height: 16),
            Text(
              'Sacred Sites Not Loaded',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the button below to load sacred sites',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadSacredSitesFromFirebase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                '聖地を読み込む',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show empty results
    if (_sacredSites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, color: Colors.white54, size: 64),
            SizedBox(height: 16),
            Text(
              'No Sacred Sites Available',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check your internet connection',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Show sacred sites grid with pagination support
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              if (scrollNotification is ScrollEndNotification) {
                final maxScroll = _scrollController.position.maxScrollExtent;
                final currentScroll = _scrollController.position.pixels;
                // Load more when scrolled to 80% of the list
                if (currentScroll >= (maxScroll * 0.8)) {
                  _loadMoreSacredSites();
                }
              }
              return false;
            },
            child: GridView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2.0,
                mainAxisSpacing: 2.0,
                childAspectRatio: 1.0,
              ),
              itemCount: _sacredSites.length + (_hasMoreSacredSites ? 1 : 0),
              itemBuilder: (context, index) {
                // Show loading indicator at the end
                if (index == _sacredSites.length) {
                  return _buildLoadingIndicator();
                }

                final site = _sacredSites[index];
                return _buildFirebaseSacredSiteItem(site);
              },
            ),
          ),
        ),

        // Bottom loading indicator for better UX
        if (_isLoadingMoreSacredSites)
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(width: 12),
                Text(
                  'さらに読み込み中...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFirebaseSacredSiteItem(SacredSite site) {
    return GestureDetector(
      onTap: () {
        // Immediate feedback - close bottom sheet instantly
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        // Call the selection callback after closing the bottom sheet
        // This makes the selection feel instant to the user
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onSacredSiteSelected(site);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Ultra-optimized image loading - NO TRANSPARENCY (0%)
              CachedNetworkImage(
                imageUrl: site.imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 200, // Increased for better clarity
                memCacheHeight: 200,
                maxWidthDiskCache: 300, // Increased for better clarity
                maxHeightDiskCache: 300,
                cacheKey: 'sacred_site_${site.id}',
                fadeInDuration: Duration(milliseconds: 150),
                fadeInCurve: Curves.easeIn,
                placeholder: (context, url) => Container(
                  color: Colors.grey[800], // Solid background, no transparency
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white54),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[800], // Solid background, no transparency
                  child: Center(
                    child: Icon(Icons.error_outline,
                        color: Colors.white54, size: 16),
                  ),
                ),
              ),

              // REMOVED gradient overlay completely for 0% transparency
              // Images will now display at full opacity and clarity

              // Optimized selection indicator - reduced transparency
              if (widget.selectedSacredSite?.id == site.id)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.greenAccent
                          .withOpacity(0.1), // Reduced from 0.15 to 0.1
                      border: Border.all(
                        color: Colors.greenAccent,
                        width: 2.0, // Slightly thicker for better visibility
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black
                              .withOpacity(0.6), // Reduced transparency
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                )
              else
                // Quick load indicator for unselected items - reduced transparency
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color:
                          Colors.black.withOpacity(0.7), // Reduced transparency
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 12, // Slightly larger for better visibility
                    ),
                  ),
                ),

              // Minimal site info badge - reduced transparency
              Positioned(
                bottom: 1,
                left: 1,
                right: 1,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        Colors.black.withOpacity(0.8), // Reduced transparency
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        site.sourceTitle.isNotEmpty
                            ? site.sourceTitle.length > 12
                                ? '${site.sourceTitle.substring(0, 12)}...'
                                : site.sourceTitle
                            : '聖地',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9, // Slightly larger for better readability
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
