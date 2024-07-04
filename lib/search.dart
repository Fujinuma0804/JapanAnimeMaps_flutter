import 'package:flutter/material.dart';

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
          '検索',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const Text(
                'アニメで検索',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20.0,
                ),
              ),
              const SizedBox(height: 20.0), // Add some spacing
              _buildImageCard(context, 'assets/images/konan.jpg', 'Text Line 1',
                  'Text Line 2'),
              const SizedBox(height: 5.0),
              _buildImageCard(context, 'assets/images/kamebashi.jpg',
                  'Text Line 3', 'Text Line 4'),
              const SizedBox(height: 5.0),
              _buildImageCard(context, 'assets/images/konan.jpg', 'Text Line 5',
                  'Text Line 6'),
              const SizedBox(height: 5.0),
              _buildImageCard(context, 'assets/images/kamebashi.jpg',
                  'Text Line 7', 'Text Line 8'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(BuildContext context, String imagePath,
      String textLine1, String textLine2) {
    return GestureDetector(
      onTap: () {
        // Handle the image tap
        print('Image tapped');
      },
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
