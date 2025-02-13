// services/scraping_service.dart
import 'dart:async';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parts/post_page/service/scraping_data.dart';

class ScrapingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Map<String, dynamic> _config = {
    'retryCount': 3,
    'retryDelay': Duration(seconds: 5),
    'userAgent': 'Mozilla/5.0 (compatible; ScrapingBot/1.0)',
  };

  Future<ScrapedData?> scrapeUrl(String url) async {
    for (var attempt = 0; attempt < _config['retryCount']; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': _config['userAgent']},
        );

        if (response.statusCode == 200) {
          final document = parse(response.body);

          return ScrapedData(
            text: await _extractText(document),
            imageUrls: await _extractImages(document),
            hashtags: await _extractHashtags(document),
            sourceUrl: url,
            scrapedAt: DateTime.now(),
          );
        }
      } catch (e) {
        print('Scraping error on attempt ${attempt + 1}: $e');
        if (attempt < _config['retryCount'] - 1) {
          await Future.delayed(_config['retryDelay']);
          continue;
        }
      }
    }
    return null;
  }

  Future<String> _extractText(Document document) async {
    try {
      final content = document.querySelector('article')?.text ?? '';
      return content.trim();
    } catch (e) {
      print('Error extracting text: $e');
      return '';
    }
  }

  Future<List<String>> _extractImages(Document document) async {
    try {
      final images = document.querySelectorAll('img');
      return images
          .map((img) => img.attributes['src'] ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error extracting images: $e');
      return [];
    }
  }

  Future<List<String>> _extractHashtags(Document document) async {
    try {
      final hashtagRegex = RegExp(r'#(\w+)');
      final text = document.body?.text ?? '';
      return hashtagRegex
          .allMatches(text)
          .map((match) => match.group(1) ?? '')
          .where((tag) => tag.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error extracting hashtags: $e');
      return [];
    }
  }

  Future<void> saveToFirestore(ScrapedData data) async {
    try {
      await _firestore.collection('scraped_posts').add({
        ...data.toJson(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving to Firestore: $e');
      throw e;
    }
  }

  Future<bool> checkDuplicate(String sourceUrl) async {
    try {
      final query = await _firestore
          .collection('scraped_posts')
          .where('sourceUrl', isEqualTo: sourceUrl)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking duplicate: $e');
      return true;
    }
  }

  Future<void> startScrapingBatch(List<String> urls) async {
    final receivePort = ReceivePort();
    await Isolate.spawn(
      _scrapeInBackground,
      _IsolateMessage(receivePort.sendPort, urls),
    );

    await for (final message in receivePort) {
      if (message is ScrapedData) {
        await saveToFirestore(message);
      } else if (message == 'done') {
        break;
      }
    }
  }
}

class _IsolateMessage {
  final SendPort sendPort;
  final List<String> urls;

  _IsolateMessage(this.sendPort, this.urls);
}

Future<void> _scrapeInBackground(_IsolateMessage message) async {
  final sendPort = message.sendPort;
  final urls = message.urls;

  for (final url in urls) {
    final scraper = ScrapingService();
    final data = await scraper.scrapeUrl(url);
    if (data != null) {
      sendPort.send(data);
    }
  }

  sendPort.send('done');
}