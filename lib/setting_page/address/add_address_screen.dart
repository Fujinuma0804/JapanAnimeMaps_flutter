import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/setting_page/address/add_address.dart';
import 'package:parts/setting_page/address/update_address.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({Key? key}) : super(key: key);

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isEditMode = false; // 編集モードの状態を管理

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          '住所一覧',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode; // 編集モードの切り替え
              });
            },
            child: Text(
              _isEditMode ? '完了' : '編集', // 編集モードに応じてテキストを変更
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF00008b),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => AddAddress()));
                },
                icon: Icon(Icons.add_circle_outline, color: Colors.white),
                label: Text(
                  '新しい住所を登録する',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00008b),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<User?>(
              stream: _auth.authStateChanges(),
              builder: (context, authSnapshot) {
                if (!authSnapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_circle_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('ログインが必要です', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(authSnapshot.data!.uid)
                      .collection('user_addresses')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('住所が登録されていません',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final address = doc.data() as Map<String, dynamic>;

                        final fullName =
                            '${address['lastName']} ${address['firstName']}';
                        final fullNameKana =
                            '${address['lastNameKana']} ${address['firstNameKana']}';

                        return Card(
                          elevation: 2,
                          margin: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.white,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                // タップ時の処理をここに追加
                              },
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.location_on,
                                                color: Color(0xFF00008b)),
                                            SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fullName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  fullNameKana,
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Divider(height: 24),
                                        Text(
                                          '〒${address['postalCode']}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '${address['prefecture']}${address['city']}${address['streetAddress']}',
                                          style: TextStyle(
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (address['building']?.isNotEmpty ??
                                            false)
                                          Text(
                                            address['building'],
                                            style: TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                        SizedBox(height: 8),
                                        Text(
                                          'TEL: ${address['phoneNumber']}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isEditMode)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit,
                                                color: Color(0xFF00008b)),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      UpdateAddress(
                                                    addressId: doc.id,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title: Text('住所の削除'),
                                                    content: Text(
                                                        'この住所を削除してもよろしいですか？'),
                                                    actions: [
                                                      TextButton(
                                                        child: Text('キャンセル'),
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                        },
                                                      ),
                                                      TextButton(
                                                        child: Text(
                                                          '削除',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.red),
                                                        ),
                                                        onPressed: () async {
                                                          try {
                                                            await _firestore
                                                                .collection(
                                                                    'users')
                                                                .doc(_auth
                                                                    .currentUser!
                                                                    .uid)
                                                                .collection(
                                                                    'user_addresses')
                                                                .doc(doc.id)
                                                                .delete();

                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                  content: Text(
                                                                      '住所を削除しました')),
                                                            );
                                                          } catch (e) {
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (BuildContext
                                                                      context) {
                                                                return AlertDialog(
                                                                  title: Text(
                                                                      'エラー'),
                                                                  content: Text(
                                                                      '削除中にエラーが発生しました: ${e.toString()}'),
                                                                  actions: [
                                                                    TextButton(
                                                                      child: Text(
                                                                          'OK'),
                                                                      onPressed:
                                                                          () {
                                                                        Navigator.of(context)
                                                                            .pop();
                                                                      },
                                                                    ),
                                                                  ],
                                                                );
                                                              },
                                                            );
                                                          }
                                                        },
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
