import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReviewNameScreen extends StatefulWidget {
  final String animeName;
  final double rating;
  final String title;
  final String review;

  ReviewNameScreen({
    required this.animeName,
    required this.rating,
    required this.title,
    required this.review,
  });

  @override
  _ReviewNameScreenState createState() => _ReviewNameScreenState();
}

class _ReviewNameScreenState extends State<ReviewNameScreen> {
  final _nicknameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
    _scrollController.addListener(_scrollListener);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'レビューを書く',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            child: Text('確認', style: TextStyle(color: Colors.blue)),
            onPressed: _submitReview,
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'レビュー用のニックネームを選択',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(
                              5,
                              (index) => Icon(Icons.star,
                                  color: index < widget.rating.floor()
                                      ? Colors.orange
                                      : Colors.grey,
                                  size: 20)),
                        ),
                        SizedBox(height: 8),
                        Text(widget.title,
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
                        SizedBox(height: 8),
                        Text(widget.review,
                            style:
                                TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _nicknameController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'ニックネーム',
                      hintStyle: TextStyle(color: Colors.white),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ニックネームはお書きになったレビューの横に表示されます。',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= _reviews.length) {
                  return _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : null;
                }
                return _buildReviewItem(_reviews[index]);
              },
              childCount: _reviews.length + 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(review['nickname'] ?? 'Anonymous',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Row(
            children: List.generate(
                5,
                (index) => Icon(Icons.star,
                    color: index < (review['rating'] ?? 0)
                        ? Colors.orange
                        : Colors.grey,
                    size: 16)),
          ),
          SizedBox(height: 8),
          Text(review['title'] ?? '',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          SizedBox(height: 4),
          Text(review['review'] ?? '',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      _fetchReviews();
    }
  }

  void _fetchReviews() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('reviews')
          .where('animeName', isEqualTo: widget.animeName)
          .orderBy('timestamp', descending: true)
          .limit(10);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      QuerySnapshot querySnapshot = await query.get();
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        setState(() {
          _reviews.addAll(querySnapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>));
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching reviews: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _submitReview() async {
    if (_nicknameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ニックネームは必須です')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('reviews').add({
        'animeName': widget.animeName,
        'rating': widget.rating,
        'title': widget.title,
        'review': widget.review,
        'nickname': _nicknameController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
