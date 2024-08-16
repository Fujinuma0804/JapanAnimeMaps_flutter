import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:translator/translator.dart';

class CustomerRequestHistoryEn extends StatefulWidget {
  @override
  _CustomerRequestHistoryEnState createState() =>
      _CustomerRequestHistoryEnState();
}

class _CustomerRequestHistoryEnState extends State<CustomerRequestHistoryEn> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user;
  final translator = GoogleTranslator();

  @override
  void initState() {
    super.initState();
    _checkUserLoggedIn();
  }

  void _checkUserLoggedIn() {
    user = _auth.currentUser;
    if (user == null) {
      // ユーザーがログインしていない場合の処理
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      setState(() {}); // ログインユーザーが見つかった場合、画面を更新
    }
  }

  Future<String> translateText(String text) async {
    var translation = await translator.translate(text, to: 'en');
    return translation.text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request history',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: user == null
          ? Center(child: Text('User not logged in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customer_animerequest')
                  .where('userEmail', isEqualTo: user!.email)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No Data'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index];
                    return FutureBuilder(
                      future: translateText(data['animeName'] ?? 'No Data'),
                      builder:
                          (context, AsyncSnapshot<String> translatedSnapshot) {
                        if (translatedSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ListTile(title: Text('Translating...'));
                        }
                        return ListTile(
                          leading: data['animeImageUrl'] != null
                              ? Image.network(data['animeImageUrl'])
                              : Text('No Image'),
                          title: Text(translatedSnapshot.data ?? 'No Data'),
                          subtitle: Text(data['location'] ?? 'No Data'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailScreen(data: data),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final QueryDocumentSnapshot data;
  final translator = GoogleTranslator();

  DetailScreen({required this.data});

  Future<String> translateText(String text) async {
    var translation = await translator.translate(text, to: 'en');
    return translation.text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder(
          future: translateText(data['animeName'] ?? 'No Data'),
          builder: (context, AsyncSnapshot<String> translatedSnapshot) {
            if (translatedSnapshot.connectionState == ConnectionState.waiting) {
              return Text('Translating...');
            }
            return Text(
              translatedSnapshot.data ?? 'No Data',
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder(
                future: translateText(
                    'Anime Name: ${data['animeName'] ?? 'No Data'}'),
                builder: (context, AsyncSnapshot<String> translatedSnapshot) {
                  if (translatedSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Text('Translating...');
                  }
                  return Text(
                    translatedSnapshot.data ?? 'No Data',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              Text(
                  'Request date and time: ${data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString() : 'No Data'}'),
              SizedBox(height: 8),
              Text('Place: ${data['location'] ?? 'No Data'}'),
              Text('Scene: ${data['scene'] ?? 'No Data'}'),
              SizedBox(height: 8),
              data['animeImageUrl'] != null
                  ? Image.network(data['animeImageUrl'])
                  : Text('No Data'),
              SizedBox(height: 8),
              data['userImageUrl'] != null
                  ? Image.network(data['userImageUrl'])
                  : Text('No Data'),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
