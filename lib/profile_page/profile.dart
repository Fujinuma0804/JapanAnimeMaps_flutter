import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'プロフィール',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        child: Column(
          children: [
            const SizedBox(
              height: 10.0,
            ),
            Stack(
              children: [
                Image.asset('assets/banner.jpg', fit: BoxFit.cover),
                Positioned(
                  bottom: 0,
                  left: 16,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: const AssetImage('assets/avatar.jpg'),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      onPressed: () {
                        // Add functionality to change avatar
                      },
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    onPressed: () {
                      // Add functionality to change banner
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            buildProfileItem('名前', 'そうた'),
            buildProfileItem('ステータスメッセージ', '未設定'),
            buildProfileItem('電話番号', '+81 80-1903-1370'),
            buildProfileItem('ID', 'applepobo321'),
            buildProfileSwitchItem('IDによる友だち追加を許可', true),
            buildProfileItem('マイQRコード', ''),
            buildProfileItem('誕生日', '2002年10月17日'),
            const SizedBox(height: 16),
            buildBGMItem('BGM'),
          ],
        ),
      ),
    );
  }

  Widget buildProfileItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.black)),
          Text(value, style: const TextStyle(color: Colors.black)),
        ],
      ),
    );
  }

  Widget buildProfileSwitchItem(String title, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.black)),
          Switch(
            value: value,
            onChanged: (bool newValue) {
              // Add functionality to handle switch change
            },
          ),
        ],
      ),
    );
  }

  Widget buildBGMItem(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.black)),
          // Add BGM slider or any widget here
        ],
      ),
    );
  }
}
