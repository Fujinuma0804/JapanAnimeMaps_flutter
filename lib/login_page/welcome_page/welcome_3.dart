import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:parts/subscription/subscription_lp.dart'; // SubscriptionLPのインポートを追加

class Welcome3 extends StatefulWidget {
  @override
  _Welcome3State createState() => _Welcome3State();
}

class _Welcome3State extends State<Welcome3>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _welcomeText = 'Loading...';
  late User _user;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    )..addListener(() {
      setState(() {});
    });

    _controller.forward();

    _getUserLanguage();
    Timer(Duration(seconds: 3), () {
      // MainScreenではなくSubscriptionLPに遷移
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => SubscriptionLP()),
      );
    });
  }

  Future<void> _getUserLanguage() async {
    _user = FirebaseAuth.instance.currentUser!;
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .get();

    if (userDoc.exists) {
      String language =
          (userDoc.data() as Map<String, dynamic>)['language'] ?? 'English';
      setState(() {
        _welcomeText = language == 'Japanese' ? 'ようこそ' : 'Welcome';
      });
    } else {
      setState(() {
        _welcomeText = 'Welcome';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Opacity(
          opacity: _animation.value,
          child: Text(
            _welcomeText,
            style: TextStyle(
              fontSize: 50.0,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00008b),
            ),
          ),
        ),
      ),
    );
  }
}