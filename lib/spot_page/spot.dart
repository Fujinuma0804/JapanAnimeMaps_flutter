import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Spot {
  final String imagePath;
  final String title;
  final String text;

  Spot(this.imagePath, this.title, this.text);

  // FirestoreドキュメントからSpotオブジェクトを生成
  factory Spot.fromDocument(DocumentSnapshot doc) {
    return Spot(
      doc['imagePath'],
      doc['title'],
      doc['text'],
    );
  }

  // SpotオブジェクトをFirestoreドキュメントに変換
  Map<String, dynamic> toDocument() {
    return {
      'imagePath': imagePath,
      'title': title,
      'text': text,
    };
  }
}

class SpotScreen extends StatelessWidget {
  const SpotScreen({Key? key}) : super(key: key);

  Future<List<Spot>> fetchSpots() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('spots').get();
    return snapshot.docs.map((doc) => Spot.fromDocument(doc)).toList();
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
      body: FutureBuilder<List<Spot>>(
        future: fetchSpots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No spots available'));
          } else {
            final spots = snapshot.data!;
            return Padding(
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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 16 / 9,
                      ),
                      itemCount: spots.length,
                      itemBuilder: (context, index) {
                        final spot = spots[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SpotDetailScreen(spot: spot),
                              ),
                            );
                          },
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Image.network(
                                  spot.imagePath,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                                Container(
                                  alignment: Alignment.bottomCenter,
                                  padding: const EdgeInsets.all(8),
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
            );
          }
        },
      ),
    );
  }
}

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
