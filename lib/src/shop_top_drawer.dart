import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parts/shop/order_history.dart';
import 'package:parts/shop/shop_cart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isLoggedIn = user != null;

        if (isLoggedIn) {
          // Firebase Authのユーザー情報を使用してFirestoreからデータを取得
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)  // Firebase AuthのUIDを使用
                .snapshots(),
            builder: (context, userSnapshot) {
              String? avatarUrl;
              if (userSnapshot.hasData && userSnapshot.data != null) {
                try {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  avatarUrl = userData?['avatarUrl'] as String?;
                  print('Retrieved avatarUrl: $avatarUrl'); // デバッグ用
                } catch (e) {
                  print('Error getting avatarUrl: $e');
                }
              }

              return _buildDrawerContent(
                context: context,
                isLoggedIn: true,
                email: user.email ?? '',
                avatarUrl: avatarUrl,
              );
            },
          );
        } else {
          // 未ログイン時のUI
          return _buildDrawerContent(
            context: context,
            isLoggedIn: false,
            email: '',
            avatarUrl: null,
          );
        }
      },
    );
  }

  Widget _buildDrawerContent({
    required BuildContext context,
    required bool isLoggedIn,
    required String email,
    String? avatarUrl,
  }) {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                      image: DecorationImage(
                        image: isLoggedIn && avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : const AssetImage('assets/images/default_profile.png')
                        as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isLoggedIn ? email : 'ログインしていません',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.notifications_outlined,
                      title: 'お知らせ',
                      onTap: () {
                        Navigator.pop(context);
                      },
                      badge: '3',
                    ),
                    if (isLoggedIn) ...[
                      const Divider(height: 1),
                      _buildMenuItem(
                        icon: Icons.local_shipping_outlined,
                        title: '注文履歴',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => OrderHistoryScreen())
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.person_outline,
                        title: 'アカウント設定',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                    const Divider(height: 1),
                    _buildMenuItem(
                      icon: Icons.help_outline,
                      title: 'ヘルプ・お問い合わせ',
                      onTap: () {
                        Navigator.pop(context);
                      },
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: Colors.black87,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.mPlusRounded1c(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}