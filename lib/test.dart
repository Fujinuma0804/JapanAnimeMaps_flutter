import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'components/ad_mob.dart';

class Test extends StatefulWidget {
  const Test({Key? key}) : super(key: key);

  @override
  State<Test> createState() => _TestState();
}

class _TestState extends State<Test> {
  final AdMob _adMob = AdMob();

  @override
  void dispose() {
    _adMob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FutureBuilder(
        future: AdSize.getAnchoredAdaptiveBannerAdSize(
          Orientation.portrait,
          MediaQuery.of(context).size.width.truncate(),
        ),
        builder: (BuildContext context,
            AsyncSnapshot<AnchoredAdaptiveBannerAdSize?> snapshot) {
          if (snapshot.hasData) {
            return SizedBox(
              width: double.infinity,
              child: _adMob.getAdBanner(),
            );
          } else {
            return Container(
              height: _adMob.getAdBannerHeight(),
              color: Colors.white,
            );
          }
        },
      ),
    );
  }
}
