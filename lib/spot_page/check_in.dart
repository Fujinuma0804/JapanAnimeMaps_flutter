import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'anime_list_detail.dart';

class SpotTestScreen extends StatefulWidget {
  const SpotTestScreen({Key? key}) : super(key: key);

  @override
  _SpotTestScreenState createState() => _SpotTestScreenState();
}

class _SpotTestScreenState extends State<SpotTestScreen>
    with SingleTickerProviderStateMixin {
  late User _user;
  late String _userId;
  late Stream<QuerySnapshot> _checkInsStream;
  bool _sortByTimestamp = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _getUser();
    _fetchCheckIns();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getUser() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    _user = auth.currentUser!;
    _userId = _user.uid;
  }

  void _fetchCheckIns() {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('check_ins');

    if (_sortByTimestamp) {
      query = query.orderBy('timestamp', descending: true);
    } else {
      query = query.orderBy('title');
    }

    _checkInsStream = query.snapshots();
  }

  void _toggleSortOrder() {
    setState(() {
      _sortByTimestamp = !_sortByTimestamp;
      _fetchCheckIns();
    });

    // 変更内容を画面中央に表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _sortByTimestamp ? Icons.access_time : Icons.sort_by_alpha,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _sortByTimestamp ? '日付順に変更しました' : 'アルファベット順に変更しました',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3498DB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToDetails(BuildContext context, String locationId) async {
    DocumentSnapshot locationSnapshot = await FirebaseFirestore.instance
        .collection('locations')
        .doc(locationId)
        .get();

    if (locationSnapshot.exists) {
      Map<String, dynamic> locationData =
      locationSnapshot.data() as Map<String, dynamic>;

      // デバッグ: imageUrlを確認
      print('Location Data: $locationData');
      print('ImageURL: ${locationData['imageUrl']}');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SpotDetailScreen(
            title: locationData['title'] ?? '',
            animeName: locationData['animeName'] ?? '',
            imageUrl: locationData['imageUrl'] ?? '',
            userId: locationData['userId'] ?? '',
            description: locationData['description'] ?? '',
            spot_description: locationData['spot_description'] ?? '',
            latitude: locationData['latitude'] as double? ?? 0.0,
            longitude: locationData['longitude'] as double? ?? 0.0,
            sourceLink: locationData['sourceLink'] as String? ?? '',
            sourceTitle: locationData['sourceTitle'] as String? ?? '',
            url: locationData['url'] as String? ?? '',
            subMedia: (locationData['subMedia'] as List?)
                ?.where((item) => item is Map<String, dynamic>)
                .cast<Map<String, dynamic>>()
                .toList() ??
                [],
            locationId: locationId,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location details not found.'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'チェックイン履歴',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF3498DB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => _toggleSortOrder(),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  _sortByTimestamp ? Icons.access_time : Icons.sort_by_alpha,
                  key: ValueKey(_sortByTimestamp),
                  color: const Color(0xFF3498DB),
                  size: 24,
                ),
              ),
              tooltip: _sortByTimestamp ? '日付順' : 'アルファベット順',
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: StreamBuilder<QuerySnapshot>(
          stream: _checkInsStream,
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 400,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF3498DB),
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade400,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'エラーが発生しました',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                height: 400,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3498DB).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_off_outlined,
                        size: 64,
                        color: Color(0xFF3498DB),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'まだチェックインした場所がありません',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '新しい場所を探索してみましょう！',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                DocumentSnapshot document = snapshot.data!.docs[index];
                Map<String, dynamic> data =
                document.data() as Map<String, dynamic>;
                String locationId = data['locationId'] ?? '';

                // デバッグ: check_insデータを確認
                print('Check-in Data: $data');
                print('LocationId: $locationId');

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('locations')
                      .doc(locationId)
                      .get(),
                  builder: (context, locationSnapshot) {
                    String imageUrl = '';
                    String title = data['title'] ?? 'タイトルなし';
                    String description = data['description'] ?? 'サブタイトルなし';

                    if (locationSnapshot.hasData && locationSnapshot.data!.exists) {
                      Map<String, dynamic> locationData =
                      locationSnapshot.data!.data() as Map<String, dynamic>;
                      imageUrl = locationData['imageUrl'] ?? '';

                      // locationsコレクションからtitleとdescriptionを取得（存在する場合）
                      title = locationData['title'] ?? data['title'] ?? 'タイトルなし';
                      description = locationData['description'] ?? data['description'] ?? 'サブタイトルなし';

                      // デバッグ: locationデータを確認
                      print('Location Data for $locationId: $locationData');
                      print('ImageURL for $locationId: $imageUrl');
                      print('Title: $title');
                      print('Description: $description');
                    }

                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Material(
                        elevation: 0,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3498DB).withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () {
                              _navigateToDetails(context, locationId);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(
                                        imageUrl,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          print('Image Error: $error');
                                          return Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF3498DB),
                                                  Color(0xFF2ECC71),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                            child: const Icon(
                                              Icons.location_on,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8F9FA),
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF3498DB),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                          : Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF3498DB),
                                              Color(0xFF2ECC71),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF7F8C8D),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2ECC71).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF2ECC71),
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}