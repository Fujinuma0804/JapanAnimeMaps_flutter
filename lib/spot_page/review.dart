import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:parts/spot_page/review_name.dart';

class ReviewPage extends StatefulWidget {
  final String animeName;

  ReviewPage({required this.animeName});

  @override
  _ReviewPageState createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  double _rating = 0;
  final _titleController = TextEditingController();
  final _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'レビューを書く',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            child: Text('次へ',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                )),
            onPressed: _navigateToReviewNameScreen,
          ),
        ],
      ),
      body: Container(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Center(
                child: RatingBar.builder(
                  initialRating: _rating,
                  minRating: 0,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemSize: 40,
                  itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                  itemBuilder: (context, index) => Icon(
                    Icons.star,
                    color: index < _rating ? Colors.yellow : Colors.yellow,
                  ),
                  unratedColor: Colors.grey.withOpacity(0.3),
                  onRatingUpdate: (rating) {
                    setState(() {
                      _rating = rating;
                    });
                  },
                ),
              ),
              Text(
                '星をタップして評価してください',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _titleController,
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'タイトル',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _reviewController,
                style: TextStyle(color: Colors.black),
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'レビュー(オプション)',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToReviewNameScreen() {
    if (_rating == 0 || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('評価とタイトルは必須です')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReviewNameScreen(
          animeName: widget.animeName,
          rating: _rating,
          title: _titleController.text,
          review: _reviewController.text,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _reviewController.dispose();
    super.dispose();
  }
}
