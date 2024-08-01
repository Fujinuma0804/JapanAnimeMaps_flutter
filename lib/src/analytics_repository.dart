import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  Future<void> logPage(String screenName) async {
    await FirebaseAnalytics.instance.logEvent(
      name: 'screen_view',
      parameters: {
        'firebase_screen': screenName,
      },
    );
  }
}
