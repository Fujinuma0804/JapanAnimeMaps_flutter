// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';

// class Spot {
//   final String imagePath;
//   final String title;
//   final String text;

//   Spot(this.imagePath, this.title, this.text);

//   // FirestoreドキュメントからSpotオブジェクトを生成
//   factory Spot.fromDocument(DocumentSnapshot doc) {
//     return Spot(
//       doc['imagePath'],
//       doc['title'],
//       doc['text'],
//     );
//   }

//   // SpotオブジェクトをFirestoreドキュメントに変換
//   Map<String, dynamic> toDocument() {
//     return {
//       'imagePath': imagePath,
//       'title': title,
//       'text': text,
//     };
//   }
// }

// class SpotScreen extends StatelessWidget {
//   const SpotScreen({Key? key}) : super(key: key);

//   Stream<List<Spot>> fetchSpotsStream() {
//     final spotsRef = FirebaseFirestore.instance
//         .collection('spots')
//         .withConverter<Spot>(
//           // Convert Firestore snapshots → Spot
//           fromFirestore: (snapshot, _) => Spot.fromDocument(snapshot),
//           // Convert Spot → Firestore docs
//           toFirestore: (spot, _) =>
//               spot.toDocument(), // ✅ Use your defined method
//         )
//         .limit(10); // Fetch first 50 docs only

//     return spotsRef.snapshots().map(
//           (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
//         );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           title: const Icon(
//             Icons.check_circle,
//             color: Color(0xFF00008b),
//           ),
//         ),
//         body: StreamBuilder<List<Spot>>(
//           stream: fetchSpotsStream(), // ✅ Use stream here
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Center(child: CircularProgressIndicator());
//             } else if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//               return const Center(child: Text('No spots available'));
//             } else {
//               final spots = snapshot.data!;
//               return Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       '■ チェクイン済みのスポット一覧',
//                       style: TextStyle(
//                         color: Color(0xFF00008b),
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Expanded(
//                       child: GridView.builder(
//                         gridDelegate:
//                             const SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: 2,
//                           crossAxisSpacing: 8,
//                           mainAxisSpacing: 8,
//                           childAspectRatio: 16 / 9,
//                         ),
//                         itemCount: spots.length,
//                         itemBuilder: (context, index) {
//                           final spot = spots[index];
//                           return GestureDetector(
//                             onTap: () {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (context) =>
//                                       SpotDetailScreen(spot: spot),
//                                 ),
//                               );
//                             },
//                             child: Card(
//                               clipBehavior: Clip.antiAlias,
//                               child: Stack(
//                                 children: [
//                                   CachedNetworkImage(
//                                     imageUrl: spot.imagePath,
//                                     fit: BoxFit.cover,
//                                     width: double.infinity,
//                                     height: double.infinity,
//                                     placeholder: (context, url) => const Center(
//                                       child: CircularProgressIndicator(
//                                           strokeWidth: 2),
//                                     ),
//                                     errorWidget: (context, url, error) =>
//                                         const Icon(Icons.error),
//                                   ),
//                                   Container(
//                                     alignment: Alignment.bottomCenter,
//                                     padding: const EdgeInsets.all(8),
//                                     child: Text(
//                                       spot.title,
//                                       style: const TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 12,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                       textAlign: TextAlign.center,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             }
//           },
//         ));
//   }
// }

// class SpotDetailScreen extends StatelessWidget {
//   final Spot spot;

//   const SpotDetailScreen({Key? key, required this.spot}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(spot.title),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Image.network(spot.imagePath),
//             const SizedBox(height: 16),
//             Text(
//               spot.title,
//               style: const TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               spot.text,
//               style: const TextStyle(fontSize: 16),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ✅ Spot Model
class Spot {
  final String imagePath;
  final String title;
  final String text;

  Spot(this.imagePath, this.title, this.text);

  // Firestore → Spot
  factory Spot.fromDocument(DocumentSnapshot doc) {
    return Spot(
      doc['imagePath'],
      doc['title'],
      doc['text'],
    );
  }

  // Spot → Firestore
  Map<String, dynamic> toDocument() {
    return {
      'imagePath': imagePath,
      'title': title,
      'text': text,
    };
  }
}

/// ✅ Firestore Service with Pagination
class SpotService {
  final spotsRef =
      FirebaseFirestore.instance.collection('spots').withConverter<Spot>(
            fromFirestore: (snapshot, _) => Spot.fromDocument(snapshot),
            toFirestore: (spot, _) => spot.toDocument(),
          );

  // fetch first page
  Future<QuerySnapshot<Spot>> fetchFirstSpots({int limit = 50}) {
    return spotsRef.limit(limit).get();
  }

  // fetch next page
  Future<QuerySnapshot<Spot>> fetchNextSpots({
    required DocumentSnapshot<Spot> lastDoc,
    int limit = 50,
  }) {
    return spotsRef.startAfterDocument(lastDoc).limit(limit).get();
  }
}

/// ✅ Spot Screen with Infinite Scroll
class SpotScreen extends StatefulWidget {
  const SpotScreen({Key? key}) : super(key: key);

  @override
  State<SpotScreen> createState() => _SpotScreenState();
}

class _SpotScreenState extends State<SpotScreen> {
  final SpotService _spotService = SpotService();
  List<Spot> _spots = [];
  DocumentSnapshot<Spot>? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialSpots();

    // add listener for infinite scroll
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !_isLoading &&
          _hasMore) {
        _loadMoreSpots();
      }
    });
  }

  Future<void> _loadInitialSpots() async {
    setState(() => _isLoading = true);
    final snapshot = await _spotService.fetchFirstSpots(limit: 50);
    setState(() {
      _spots = snapshot.docs.map((doc) => doc.data()).toList();
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _isLoading = false;
      _hasMore = snapshot.docs.length == 50; // if less than 50, no more
    });
  }

  Future<void> _loadMoreSpots() async {
    if (_lastDoc == null) return;

    setState(() => _isLoading = true);
    final snapshot =
        await _spotService.fetchNextSpots(lastDoc: _lastDoc!, limit: 50);
    setState(() {
      _spots.addAll(snapshot.docs.map((doc) => doc.data()).toList());
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastDoc;
      _isLoading = false;
      _hasMore = snapshot.docs.length == 50;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Icon(
          Icons.check_circle,
          color: Color(0xFF00008b),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '■ チェクイン済みのスポット一覧',
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                controller: _scrollController,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: _spots.length,
                itemBuilder: (context, index) {
                  final spot = _spots[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SpotDetailScreen(spot: spot),
                        ),
                      );
                    },
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: spot.imagePath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Icons.image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                          Container(
                            alignment: Alignment.bottomCenter,
                            padding: const EdgeInsets.all(8),
                            color: Colors.black45,
                            child: Text(
                              spot.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ Spot Detail Screen
class SpotDetailScreen extends StatelessWidget {
  final Spot spot;

  const SpotDetailScreen({Key? key, required this.spot}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(spot.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(spot.imagePath),
            const SizedBox(height: 16),
            Text(
              spot.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              spot.text,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
