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
        backgroundColor: Colors.white,
        title: const Text(
          '使い方',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20.0),
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
              const SizedBox(height: 10.0),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('日々追加されるスポットへたくさんチェックインしよう。'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('チェックインすると画像投稿が可能に！！'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('投稿して同じアニメの好きな友達をフォローしよう！'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('チェックインや投稿で溜めたポイントを豪華景品へ交換！'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('景品については、数に限りがあります。'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('景品の一部は告知なしで終了する可能性があります。'),
              ),
              const SizedBox(
                height: 15.0,
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '■ 参加方法',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 10.0),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('本アプリに登録し、ログインした状態でチェックイン'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('利用方法を参考に、たくさんチェックイン・投稿をしよう'),
              ),
              const SizedBox(
                height: 15.0,
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
              const SizedBox(height: 10.0),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('①スポット付近でチェックインができるようになります。'),
              ),
              const SizedBox(
                height: 10.0,
              ),
              Center(
                child: SizedBox(
                  height: 400,
                  width: 300,
                  child: Image.asset('assets/images/sample_images.png'),
                ),
              ),
              const SizedBox(
                height: 10.0,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('②チェックインを押し、アニメの題名を入力します。'),
              ),
              const SizedBox(
                height: 10.0,
              ),
              Center(
                child: SizedBox(
                  height: 400,
                  width: 300,
                  child: Image.asset('assets/images/sample_checkin.png'),
                ),
              ),
              const SizedBox(
                height: 10.0,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('③アニメの題名が正しければチェックイン完了です！！'),
              ),
              const SizedBox(
                height: 15.0,
              ),
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
              const SizedBox(height: 10.0),
              Table(
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
              const SizedBox(height: 5.0),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '※事情により予告なく変更となる可能性があります。',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(
                height: 10.0,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('溜まったポイントは豪華景品へと交換可能！'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text('たくたんチェックイン・投稿で豪華景品をゲットしよう！'),
              ),
              const SizedBox(height: 50.0), // Extra space at the bottom
            ],
          ),
        ),
      ),
    );
  }
}
