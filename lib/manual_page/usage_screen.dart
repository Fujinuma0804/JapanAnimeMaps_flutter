import 'package:flutter/material.dart';

class UsageScreen extends StatefulWidget {
  const UsageScreen({Key? key}) : super(key: key);

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '使い方',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(
            height: 20.0,
          ),
          const Center(
            child: Text(
              '獲得ポイントをランキング形式で毎週発表！\n',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(
            height: 10.0,
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '■ 利用方法',
              textAlign: TextAlign.start,
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(
            height: 10.0,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: Text('スポットへ行くとチェックインができるようになります。'),
          ),
          const Text('画像添付する'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: Text('チェックインするとアニメ名を入力すると投稿ができるようになります。'),
          ),
          const Text('画像添付する'),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '■ ポイント情報',
              textAlign: TextAlign.start,
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(
            height: 10.0,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0), // Add padding to both sides
            child: Table(
              border: TableBorder.all(
                color: Colors.black,
                width: 1.0,
                style: BorderStyle.solid,
              ),
              children: const [
                TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('チェックイン'),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('１ポイント'),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('投稿'),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('２ポイント'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 5.0,
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              '※事情により変更となる可能性があります。',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
