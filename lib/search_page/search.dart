import 'package:flutter/material.dart';
import 'package:parts/spot_page/spot.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '巡礼スポット',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SpotScreen()),
            );
          },
          icon: const Icon(
            Icons.check_circle,
            color: Color(0xFF00008b),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Align items to the left
            children: [
              const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.0), // Add some padding
                child: Text(
                  '■ 人気のアニメ一覧',
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 10.0), // Add some spacing
              _buildImageCard(
                context,
                'assets/images/picture_sample.png',
                '名探偵コナン',
                '青山剛昌',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DetailPage(
                      title: '名探偵コナン',
                      description: '青山剛昌',
                      imagePath: 'assets/images/picture_sample.png',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5.0),
              _buildImageCard(
                context,
                'assets/images/picture_sample.png',
                'Text Line 3',
                'Text Line 4',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DetailPage(
                      title: 'Text Line 3',
                      description: 'Text Line 4',
                      imagePath: 'assets/images/picture_sample.png',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5.0),
              _buildImageCard(
                context,
                'assets/images/picture_sample.png',
                'Text Line 5',
                'Text Line 6',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DetailPage(
                      title: 'Text Line 5',
                      description: 'Text Line 6',
                      imagePath: 'assets/images/picture_sample.png',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5.0),
              _buildImageCard(
                context,
                'assets/images/picture_sample.png',
                'Text Line 7',
                'Text Line 8',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DetailPage(
                      title: 'Text Line 7',
                      description: 'Text Line 8',
                      imagePath: 'assets/images/picture_sample.png',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(BuildContext context, String imagePath,
      String textLine1, String textLine2, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Image.asset(
            imagePath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: MediaQuery.of(context).size.height /
                3, // Adjust height as needed
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height /
                  6, // Adjust filter height as needed
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textLine1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                      ),
                    ),
                    Text(
                      textLine2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailPage extends StatelessWidget {
  final String title;
  final String description;
  final String imagePath;

  const DetailPage({
    Key? key,
    required this.title,
    required this.description,
    required this.imagePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Column(
        children: [
          Image.asset(imagePath),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              description,
              style: const TextStyle(fontSize: 18.0),
            ),
          ),
        ],
      ),
    );
  }
}
