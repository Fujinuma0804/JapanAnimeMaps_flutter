import 'package:flutter/material.dart';
import 'package:parts/setting_page/add_address.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({Key? key}) : super(key: key);

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
            onPressed: () {},
            child: Text(
              '編集',
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
          TextButton(
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => AddAddress()));
            },
            child: Text(
              '新しい住所を登録する',
              style: TextStyle(
                color: Color(0xFF00008b),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
