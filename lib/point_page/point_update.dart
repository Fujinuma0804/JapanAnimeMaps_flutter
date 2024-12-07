import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/point_page/point_manual.dart';
import 'package:parts/point_page/points_history_page.dart';

import '../manual_page/manual_en.dart';
import '../manual_page/privacypolicy_screen.dart';
import '../manual_page/terms_screen.dart';
import 'chenged_point.dart';

class UserPointUpdatePage extends StatefulWidget {
  const UserPointUpdatePage({Key? key}) : super(key: key);

  @override
  _UserPointUpdatePageState createState() => _UserPointUpdatePageState();
}

class _UserPointUpdatePageState extends State<UserPointUpdatePage> {
  String _language = 'English';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<DocumentSnapshot> _languageSubscription;
  late StreamSubscription<DocumentSnapshot> _pointSubscription;
  final TextEditingController _rankingNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _monitorLanguageChange();
    _monitorPointChange();
    _checkRankingName();
  }

  @override
  void dispose() {
    _languageSubscription.cancel();
    _pointSubscription.cancel();
    _rankingNameController.dispose();
    super.dispose();
  }

  Future<void> _checkRankingName() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final rankingName = doc.data()?['ranking_name'];
        if (rankingName == null || rankingName.toString().isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showRankingNameDialog();
          });
        }
      }
    }
  }

  Future<void> _showRankingNameDialog() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final storedId = userDoc.data()?['id'] as String? ?? 'Unknown';

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            _language == '日本語' ? 'ランキング表示名の設定' : 'Set Ranking Display Name',
            style: const TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _language == '日本語'
                    ? '表示する名前を入力してください。\n設定しない場合にはIDが表示されます。\n登録後も変更できます。'
                    : 'Please enter the name to be displayed in rankings.\nIf not set, the ID will be displayed.\nYou can change it after registration.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _rankingNameController,
                decoration: InputDecoration(
                  hintText: _language == '日本語' ? '表示名' : 'Display Name',
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00008b), width: 2),
                  ),
                ),
                maxLength: 10,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(
                _language == '日本語' ? '登録しない' : 'Skip',
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'ranking_name': storedId});
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            TextButton(
              child: Text(
                _language == '日本語' ? '登録' : 'Register',
                style: const TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                if (_rankingNameController.text.trim().isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({
                    'ranking_name': _rankingNameController.text.trim(),
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _language == '日本語'
                            ? '表示名を入力してください'
                            : 'Please enter a display name',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _monitorLanguageChange() {
    User? user = _auth.currentUser;
    if (user != null) {
      _languageSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final newLanguage = snapshot.data()?['language'] as String?;
          if (newLanguage != null) {
            setState(() {
              _language = newLanguage == 'Japanese' ? '日本語' : 'English';
            });
          }
        }
      });
    }
  }

  void _monitorPointChange() {
    User? user = _auth.currentUser;
    if (user != null) {
      _pointSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists) {
          final correctCount = snapshot.data()?['correctCount'] as int?;
          final lastCorrectCount = snapshot.data()?['lastCorrectCount'] as int?;
          final currentPoint = snapshot.data()?['Point'] as int?;
          final currentPoints = snapshot.data()?['points'] as int?;

          // Points と Point が存在しない場合は作成
          if (currentPoint == null && currentPoints == null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'Point': 0,
              'points': 0,
            });
          }

          if (correctCount != null) {
            if (lastCorrectCount == null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                'Point': correctCount,
                'lastCorrectCount': correctCount
              });
            } else if (correctCount > lastCorrectCount) {
              int increase = correctCount - lastCorrectCount;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                'Point': FieldValue.increment(increase),
                'lastCorrectCount': correctCount
              });
            }
          }
        }
      });
    }
  }

  int _getPointValue(Map<String, dynamic> userData) {
    final rawPoint = userData['Point'] ?? 0;
    final rawPoints = userData['points'] ?? 0;

    int point = 0;
    int points = 0;

    // Point値の取得
    if (rawPoint is int) {
      point = rawPoint;
    } else if (rawPoint is String) {
      point = int.tryParse(rawPoint) ?? 0;
    }

    // points値の取得
    if (rawPoints is int) {
      points = rawPoints;
    } else if (rawPoints is String) {
      points = int.tryParse(rawPoints) ?? 0;
    }

    // pointsとPointを比較し、大きい方を返す
    // 同率の場合はpointsを優先
    return points >= point ? points : point;
  }

  String _getRankMessage(int index) {
    if (_language == '日本語') {
      switch (index) {
        case 0:
          return '🎉 トップランカー！';
        case 1:
          return '素晴らしい成績！';
        case 2:
          return 'がんばっています！';
        default:
          return '';
      }
    } else {
      switch (index) {
        case 0:
          return '🎉 Top Ranker!';
        case 1:
          return 'Great Performance!';
        case 2:
          return 'Keep it up!';
        default:
          return '';
      }
    }
  }

  Widget _buildPointRanking() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              _language == '日本語'
                  ? 'ランキングデータがありません'
                  : 'No ranking data available',
            ),
          );
        }

        final sortedDocs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aPoint = _getPointValue(a.data() as Map<String, dynamic>);
            final bPoint = _getPointValue(b.data() as Map<String, dynamic>);
            return bPoint.compareTo(aPoint);
          });

        final topDocs = sortedDocs.take(10).toList();

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _language == '日本語' ? 'ポイントランキング' : 'Point Ranking',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00008b),
                  ),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topDocs.length,
                itemBuilder: (context, index) {
                  final userData =
                      topDocs[index].data() as Map<String, dynamic>;
                  final displayName =
                      userData['ranking_name'] ?? userData['id'] ?? 'Unknown';
                  final points = _getPointValue(userData);

                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                  final isCurrentUser = topDocs[index].id == currentUserId;

                  Widget rankWidget;
                  if (index < 3) {
                    rankWidget = Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          size: 40,
                          color: index == 0
                              ? const Color(0xFFFFD700)
                              : index == 1
                                  ? const Color(0xFFC0C0C0)
                                  : const Color(0xFFCD7F32),
                        ),
                        Positioned(
                          bottom: 5,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    rankWidget = Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          isCurrentUser ? Colors.blue.withOpacity(0.1) : null,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: rankWidget,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontWeight: isCurrentUser
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                              if (index < 3)
                                Text(
                                  _getRankMessage(index),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: index < 3
                                ? const Color(0xFF00008b).withOpacity(0.1)
                                : null,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            '$points pt',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00008b),
                              fontSize: index < 3 ? 18 : 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          _language == '日本語' ? 'ポイント' : 'Points',
          style: const TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
            ),
            color: Colors.black,
            onPressed: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (context) => ManualEn()));
            },
          ),
        ],
      ),
      body: currentUser == null
          ? Center(
              child: Text(
                _language == '日本語' ? 'ログインしていません' : 'Not logged in',
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                        return Center(
                          child: Text(
                            _language == '日本語'
                                ? 'データが見つかりません'
                                : 'No data found',
                          ),
                        );
                      }

                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      final point = _getPointValue(userData);

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .snapshots(),
                        builder: (context, rankingSnapshot) {
                          int userRank = 0;
                          int totalUsers = 0;
                          if (rankingSnapshot.hasData) {
                            final sortedDocs =
                                rankingSnapshot.data!.docs.toList()
                                  ..sort((a, b) {
                                    final aPoint = _getPointValue(
                                        a.data() as Map<String, dynamic>);
                                    final bPoint = _getPointValue(
                                        b.data() as Map<String, dynamic>);
                                    return bPoint.compareTo(aPoint);
                                  });

                            totalUsers = sortedDocs.length;

                            for (int i = 0; i < sortedDocs.length; i++) {
                              if (sortedDocs[i].id == currentUser.uid) {
                                userRank = i + 1;
                                break;
                              }
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  _language == '日本語' ? 'あなたの成績' : 'Your Status',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00008b),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00008b),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.grey.withOpacity(0.5),
                                              spreadRadius: 5,
                                              blurRadius: 7,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              _language == '日本語'
                                                  ? 'ポイント'
                                                  : 'Points',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '$point pt',
                                              style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00008b),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.grey.withOpacity(0.5),
                                              spreadRadius: 5,
                                              blurRadius: 7,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              _language == '日本語'
                                                  ? 'ランキング'
                                                  : 'Ranking',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '$userRank',
                                                  style: const TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  _language == '日本語'
                                                      ? ' /$totalUsers位'
                                                      : ' /$totalUsers',
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  _buildPointRanking(),
                ],
              ),
            ),
      drawer: Drawer(
        child: ListView(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                String currentName = '';
                if (snapshot.hasData && snapshot.data!.exists) {
                  currentName =
                      snapshot.data!.get('ranking_name')?.toString() ?? '';
                }

                return ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(
                      _language == '日本語' ? "ランキングネームの編集" : "Edit Ranking Name"),
                  subtitle: currentName.isNotEmpty
                      ? Text(
                          currentName,
                          style: const TextStyle(fontSize: 12),
                        )
                      : Text(
                          _language == '日本語' ? "未設定" : "Not set",
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                  onTap: () {
                    Navigator.pop(context);
                    _rankingNameController.text = currentName;
                    _showRankingNameDialog();
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_chart_outlined),
              title:
                  Text(_language == '日本語' ? "ポイントの貯め方" : "How to Earn Points"),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => PointManual()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_chart_outlined),
              title: Text(_language == '日本語' ? "ポイント履歴" : "Point history"),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PointsHistoryPage(
                              userId: '',
                            )));
              },
            ),
            ListTile(
              leading: const Icon(Icons.money),
              title: Text(_language == '日本語' ? "ポイント交換" : "Exchange Points"),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PresentListScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.book_outlined),
              title: Text(_language == '日本語' ? "ポイント利用規約" : "Terms of Use"),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => TermsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(_language == '日本語' ? "プライバシーポリシー" : "Privacy Policy"),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PrivacyPolicyScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
