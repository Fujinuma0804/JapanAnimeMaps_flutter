import 'package:flutter/material.dart';
import 'package:parts/spot_page/spot_detail.dart';

class Spot {
  final String imagePath;
  final String title;
  final String text;

  Spot(this.imagePath, this.title, this.text);
}

class SpotScreen extends StatelessWidget {
  const SpotScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Spot> spots = [
      Spot('assets/images/kamebashi.jpg', '亀橋付近', 'TVアニメ第１弾キービジュアルに描かれている場所。'),
      Spot('assets/images/kamebashi.jpg', '小島橋 バス停(1話)',
          'TVアニメ第１弾キービジュアルに描かれている場所。'),
      Spot('assets/images/kamebashi.jpg', '中央茶廊前(1話)',
          'TVアニメ第１弾キービジュアルに描かれている場所。'),
      Spot('assets/images/kamebashi.jpg', '銀座通り(1話)',
          'TVアニメ第１弾キービジュアルに描かれている場所。'),
      Spot('assets/images/kamebashi.jpg', '慶応橋(4話)',
          'TVアニメ第１弾キービジュアルに描かれている場所。'),
      Spot('assets/images/kamebashi.jpg', '一本杉通り banco前(8話)',
          'TVアニメ第１弾キービジュアルに描かれている場所。'),
      Spot('assets/images/kamebashi.jpg', 'ミナ.クル前(1話)',
          'TVアニメ第１弾キービジュアルに描かれている場所。'),
      Spot('assets/images/kamebashi.jpg', '長生橋(2話)',
          'TVアニメ第１弾キービジュアルに描かれている場所。'),
    ];

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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                          builder: (context) => SpotDetailScreen(spot: spot),
                        ),
                      );
                    },
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Image.asset(
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
      ),
    );
  }
}
