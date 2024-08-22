import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'welcome_2.dart'; // Update import based on your directory structure

class Welcome1 extends StatefulWidget {
  @override
  _Welcome1State createState() => _Welcome1State();
}

class _Welcome1State extends State<Welcome1> {
  String _welcomeTitle = 'JAMへようこそ'; // Default to Japanese text
  String _welcomeDescription =
      'JAMアプリで聖地巡礼をより楽しく。\nポイントも貯まって、同じアニメが好きなユーザと交流しよう。';

  @override
  void initState() {
    super.initState();
    _getUserLanguage();
  }

  Future<void> _getUserLanguage() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        String language =
            (userDoc.data() as Map<String, dynamic>)['language'] ?? 'English';
        setState(() {
          _welcomeTitle =
              language == 'Japanese' ? 'JAMへようこそ' : 'Welcome to JAM';
          _welcomeDescription = language == 'Japanese'
              ? 'JAMアプリで聖地巡礼をより楽しく。\nポイントも貯まって、同じアニメが好きなユーザと交流しよう。'
              : 'Make your pilgrimage more enjoyable with the JAM app.\nEarn points and interact with users who like the same anime.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            // Display image
            Image.asset(
              'assets/images/Welcome-amico.png', // Update this path based on your assets
              height: 200,
            ),
            SizedBox(height: 40),
            // Title text
            Text(
              _welcomeTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            // Description text
            Text(
              _welcomeDescription,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            Spacer(),
            // Next button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => Welcome2()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0B3D91), // Button background color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
                child: Text(
                  _welcomeTitle == 'JAMへようこそ' ? '次へ' : 'Next',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
