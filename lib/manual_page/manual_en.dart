import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:parts/help_page/qa/contact_form.dart';
import 'package:parts/login_page/welcome_page/welcome_1.dart';
import 'package:parts/shiori/shiori_make.dart';
import 'package:parts/subscription/payment_subscription.dart';
import 'package:settings_ui/settings_ui.dart';

import '../setting_page/settings_en.dart';
import '../web_page/website.dart';

class ManualEn extends StatefulWidget {
  const ManualEn({Key? key});

  @override
  _ManualEnState createState() => _ManualEnState();
}

class _ManualEnState extends State<ManualEn> {
  String _language = 'English';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<DocumentSnapshot> _languageSubscription;

  @override
  void initState() {
    super.initState();
    _monitorLanguageChange();
  }

  @override
  void dispose() {
    _languageSubscription.cancel();
    super.dispose();
  }

  final InAppReview inAppReview = InAppReview.instance;

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            _language == '日本語' ? 'その他' : 'Others',
            style: const TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: SettingsList(
          lightTheme: const SettingsThemeData(),
          sections: [
            SettingsSection(
              title: Text(_language == '日本語' ? '設定' : 'Settings'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(_language == '日本語' ? '設定' : 'Settings'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsEn()),
                    );
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text(_language == '日本語' ? 'お問い合わせ' : 'Contact'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.people_alt_outlined),
                  title: Text(_language == '日本語' ? 'お問い合わせはこちらから' : 'Click here to contact us'),
                  value: const Text(''),
                  onPressed: (context) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ContactFormPage()),
                    );
                  },
                ),
              ],
            ),
            // SettingsSection(
            //   title: Text(_language == '日本語' ? '利用方法' : 'How to Use'),
            //   tiles: <SettingsTile>[
            //     SettingsTile.navigation(
            //       leading: const Icon(Icons.bookmarks_sharp),
            //       title: Text(_language == '日本語' ? '利用方法' : 'How to Use'),
            //       value: Text(_language == '日本語' ? '現在調整中…' : 'Under adjustment'),
            //       onPressed: (context) {
            //         // Navigator.push(context,
            //         //     MaterialPageRoute(builder: (context) => UsageScreen()));
            //       },
            //     ),
            //   ],
            // ),
            SettingsSection(
              title: Text(_language == '日本語' ? 'レビュー' : 'Review'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.star_rounded),
                  title: Text(_language == '日本語' ? 'このアプリをレビューする' : 'Review this app'),
                  value: const Text(''),
                  onPressed: (context) {
                    inAppReview.openStoreListing(appStoreId: '6608967051', microsoftStoreId: '...');
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text(_language == '日本語' ? '有料プラン' : 'Paid plan'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.payment_rounded),
                  title: Text(_language == '日本語' ? 'JAMプレミアム' : 'JAM Premium'),
                  value: const Text(''),
                  onPressed: (context) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const PaymentSubscriptionScreen(),
                    );
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text(_language == '日本語' ? '公式' : 'Official'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.phonelink),
                  title: Text(_language == '日本語' ? '公式サイト' : 'Official Site'),
                  value: const Text(''),
                  onPressed: (context) {
                    // 現在のユーザーを取得
                    User? user = _auth.currentUser;
                    if (user != null) {
                      // Firestoreからユーザーのlanguage設定を取得
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .get()
                          .then((snapshot) {
                        if (snapshot.exists) {
                          String language =
                              snapshot.data()?['language'] ?? 'English';
                          // 言語に応じて適切な画面に遷移
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => language == 'Japanese'
                                  ? const OfficialSiteScreen()
                                  : const OfficialSiteScreen(),
                            ),
                          );
                        }
                      });
                    }
                  },
                ),
              ],
            ),
            // SettingsSection(
            //   title: Text(_language == '日本語' ? 'テスト' : 'TestMode'),
            //   tiles: <SettingsTile>[
            //     SettingsTile.navigation(
            //       leading: const Icon(Icons.deselect_sharp),
            //       title: Text(_language == '日本語' ? 'テスト' : 'TestMode'),
            //       value: const Text(''),
            //       onPressed: (context) {
            //         showModalBottomSheet(
            //           context: context,
            //           isScrollControlled: true,
            //           backgroundColor: Colors.transparent,
            //           //画面のテストはこちらを変更して遷移先に指定してください。
            //           builder: (context) => ShioriMakePage(),
            //         );
            //       },
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }
}
