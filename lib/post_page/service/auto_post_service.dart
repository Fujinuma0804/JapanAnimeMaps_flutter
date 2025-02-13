// // lib/services/auto_post_service.dart
//
// import 'dart:async';
// import 'dart:math';
// import 'package:http/http.dart' as http;
// import 'package:html/parser.dart' show parse;
// import 'package:html/dom.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'scraped_content.dart';
// import 'rate_limiter.dart';
//
// class AutoPostService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final RateLimiter _rateLimiter = RateLimiter();
//   final Map<String, Timer> _timers = {};
//   final Map<String, int> _errorCounts = {};
//   static const int maxTextLength = 1000;
//   static const int maxMediaCount = 4;
//
//   Future<ScrapedContent?> scrapeContent(AutoPostConfig config) async {
//     if (!_rateLimiter.canAccess(config.sourceUrl)) {
//       await _logError(config.sourceUrl, 'Rate limit exceeded', isRateLimit: true);
//       return null;
//     }
//
//     try {
//       if (await _isBlockedByRobotsTxt(config.sourceUrl)) {
//         await _logError(config.sourceUrl, 'Blocked by robots.txt', isFatal: true);
//         return null;
//       }
//
//       final errorCount = _errorCounts[config.sourceUrl] ?? 0;
//       if (errorCount >= config.maxRetries) {
//         await _logError(config.sourceUrl, 'Max retries exceeded', isFatal: true);
//         stopAutoPosting(config.sourceUrl);
//         return null;
//       }
//
//       final response = await http.get(
//         Uri.parse(config.sourceUrl),
//         headers: {
//           ...config.headers,
//           'Accept-Encoding': 'gzip, deflate',
//         },
//       );
//
//       _rateLimiter.trackAccess(config.sourceUrl);
//
//       if (response.statusCode == 429) {
//         await _handleTooManyRequests(config);
//         return null;
//       }
//
//       if (response.statusCode != 200) {
//         await _handleHttpError(config, response.statusCode);
//         return null;
//       }
//
//       _errorCounts[config.sourceUrl] = 0;
//       final document = parse(response.body);
//       final content = document.querySelector(config.selector);
//
//       if (content == null) {
//         await _logError(config.sourceUrl, 'Content not found with selector: ${config.selector}');
//         return null;
//       }
//
//       final text = _cleanText(content.text);
//       if (text.isEmpty) {
//         await _logError(config.sourceUrl, 'Empty content after cleaning');
//         return null;
//       }
//
//       return ScrapedContent(
//         text: text.length > maxTextLength
//             ? '${text.substring(0, maxTextLength)}...'
//             : text,
//         mediaUrls: await _extractMediaUrls(content, config.sourceUrl),
//         hashtags: _extractHashtags(content.text),
//         sourceUrl: config.sourceUrl,
//       );
//
//     } catch (e) {
//       await _handleError(config, error: e.toString());
//       return null;
//     }
//   }
//
//   Future<bool> _isBlockedByRobotsTxt(String url) async {
//     try {
//       final uri = Uri.parse(url);
//       final robotsUrl = '${uri.scheme}://${uri.host}/robots.txt';
//       final response = await http.get(Uri.parse(robotsUrl));
//
//       if (response.statusCode != 200) return false;
//
//       final robotsTxt = response.body.toLowerCase();
//       final path = uri.path.toLowerCase();
//
//       return robotsTxt.contains('user-agent: *') &&
//           robotsTxt.split('\n').any((line) =>
//           line.trim().startsWith('disallow:') &&
//               path.startsWith(line.split(':')[1].trim()));
//     } catch (e) {
//       print('Error checking robots.txt: $e');
//       return false;
//     }
//   }
//
//   Future<void> _handleError(AutoPostConfig config, {String? error}) async {
//     _errorCounts[config.sourceUrl] = (_errorCounts[config.sourceUrl] ?? 0) + 1;
//     await _logError(config.sourceUrl, error ?? 'Unknown error');
//
//     final waitMinutes = pow(2, _errorCounts[config.sourceUrl] ?? 1).toInt();
//     await _pausePosting(config, duration: Duration(minutes: waitMinutes));
//   }
//
//   Future<void> _handleHttpError(AutoPostConfig config, int statusCode) async {
//     await _logError(
//         config.sourceUrl,
//         'HTTP error: $statusCode',
//         isFatal: statusCode >= 400 && statusCode < 500
//     );
//
//     if (statusCode >= 500) {
//       await _pausePosting(config, duration: const Duration(minutes: 30));
//     } else {
//       await _handleError(config);
//     }
//   }
//
//   Future<void> _handleTooManyRequests(AutoPostConfig config) async {
//     await _logError(config.sourceUrl, 'Too Many Requests', isRateLimit: true);
//     await _pausePosting(config, duration: const Duration(hours: 1));
//   }
//
//   Future<void> _pausePosting(AutoPostConfig config, {Duration? duration}) async {
//     stopAutoPosting(config.sourceUrl);
//
//     if (duration != null) {
//       await Future.delayed(duration);
//       startAutoPosting(config);
//     }
//   }
//
//   String _cleanText(String text) {
//     return text
//         .trim()
//         .replaceAll(RegExp(r'\s+'), ' ')
//         .replaceAll(RegExp(r'[\n\r]+'), '\n');
//   }
//
//   List<String> _extractHashtags(String text) {
//     final hashtagRegex = RegExp(r'#(\w+)');
//     return hashtagRegex
//         .allMatches(text)
//         .map((m) => m.group(1) ?? '')
//         .where((tag) => tag.isNotEmpty)
//         .toSet()
//         .toList();
//   }
//
//   Future<List<String>> _extractMediaUrls(Element element, String baseUrl) async {
//     final urls = <String>{};
//
//     for (var img in element.querySelectorAll('img')) {
//       final src = img.attributes['src'];
//       if (src != null && src.isNotEmpty) {
//         urls.add(_resolveUrl(src, baseUrl));
//       }
//       if (urls.length >= maxMediaCount) break;
//     }
//
//     return urls.toList();
//   }
//
//   String _resolveUrl(String url, String baseUrl) {
//     if (url.startsWith('http')) return url;
//
//     final uri = Uri.parse(baseUrl);
//     if (url.startsWith('/')) {
//       return '${uri.scheme}://${uri.host}$url';
//     }
//     return '${uri.scheme}://${uri.host}${uri.path}/$url';
//   }
//
//   Future<void> _logError(
//       String url,
//       String error, {
//         bool isRateLimit = false,
//         bool isFatal = false,
//       }) async {
//     try {
//       await _firestore.collection('scraping_errors').add({
//         'url': url,
//         'error': error,
//         'timestamp': FieldValue.serverTimestamp(),
//         'isRateLimit': isRateLimit,
//         'isFatal': isFatal,
//       });
//     } catch (e) {
//       print('Error logging error: $e');
//     }
//   }
//
//   Future<bool> _isDuplicate(String text) async {
//     final snapshot = await _firestore
//         .collection('posts')
//         .where('text', isEqualTo: text)
//         .limit(1)
//         .get();
//
//     return snapshot.docs.isNotEmpty;
//   }
//
//   void startAutoPosting(AutoPostConfig config) {
//     stopAutoPosting(config.sourceUrl);
//
//     _timers[config.sourceUrl] = Timer.periodic(config.interval, (_) async {
//       if (!config.isActive) return;
//
//       final content = await scrapeContent(config);
//       if (content != null && !await _isDuplicate(content.text)) {
//         await _createPost(content);
//       }
//     });
//   }
//
//   Future<void> _createPost(ScrapedContent content) async {
//     try {
//       await _firestore.collection('posts').add({
//         'text': content.text,
//         'mediaUrls': content.mediaUrls,
//         'hashtags': content.hashtags,
//         'userId': 'system',
//         'userHandle': 'system',
//         'createdAt': FieldValue.serverTimestamp(),
//         'likes': 0,
//         'likedBy': [],
//         'retweets': 0,
//         'retweetedBy': [],
//         'bookmarkedBy': [],
//         'commentCount': 0,
//         'source': {
//           'url': content.sourceUrl,
//           'isAuto': true,
//         },
//       });
//     } catch (e) {
//       print('Error creating post: $e');
//       throw e;
//     }
//   }
//
//   void stopAutoPosting(String url) {
//     _timers[url]?.cancel();
//     _timers.remove(url);
//   }
//
//   void dispose() {
//     for (var timer in _timers.values) {
//       timer.cancel();
//     }
//     _timers.clear();
//     _errorCounts.clear();
//   }
// }