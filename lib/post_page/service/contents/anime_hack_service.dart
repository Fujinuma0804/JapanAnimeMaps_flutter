// // lib/services/anime_hack_service.dart
//
// import 'package:html/parser.dart' show parse;
// import 'package:http/http.dart' as http;
// import 'package:parts/post_page/service/contents/anime_hack_config.dart';
// import 'package:parts/post_page/service/scraped_content.dart';
//
// class AnimeHackService {
//   final _config = AnimeHackScrapingConfig.selectors;
//
//   Future<List<ScrapedContent>> scrapeRanking() async {
//     try {
//       final response = await http.get(
//         Uri.parse(animeHackConfig.sourceUrl),
//         headers: animeHackConfig.headers,
//       );
//
//       if (response.statusCode != 200) {
//         throw Exception('Failed to load page: ${response.statusCode}');
//       }
//
//       final document = parse(response.body);
//       final articles = document.querySelectorAll('.rankingList');
//       final List<ScrapedContent> contents = [];
//
//       for (var article in articles) {
//         try {
//           // 必須フィールドの取得と検証
//           final titleElement = article.querySelector(_config['title']);
//           final contentElement = article.querySelector(_config['content']);
//
//           if (titleElement == null || contentElement == null) {
//             continue;
//           }
//
//           final title = titleElement.text;
//           final content = contentElement.text;
//
//           if (title.isEmpty || content.isEmpty) {
//             continue;
//           }
//
//           // オプショナルフィールドの取得とデフォルト値の設定
//           final rank = article.querySelector(_config['rank'])?.text.replaceAll('位', '').trim() ?? '0';
//           final url = titleElement.attributes['href'] ?? '';
//           final date = article.querySelector(_config['date'])?.text.trim() ?? '';
//           final categoryElement = article.querySelector(_config['category']);
//           final category = categoryElement?.attributes['alt']?.trim() ?? 'その他';
//
//           // タグの取得と型変換
//           final tagElements = article.querySelectorAll(_config['tags']);
//           final tags = tagElements
//               .map((e) => e.text.trim())
//               .where((tag) => tag.isNotEmpty)
//               .take(AnimeHackScrapingConfig.maxTags)
//               .toList();
//
//           // サムネイル画像URLの処理
//           final thumbnailElement = article.querySelector(_config['thumbnail']);
//           final thumbnail = thumbnailElement?.attributes['src']?.trim() ?? '';
//           final mediaUrls = thumbnail.isNotEmpty ? [thumbnail] : <String>[];
//
//           // フルURLの構築
//           final fullUrl = url.isNotEmpty
//               ? 'https://anime.eiga.com$url'
//               : animeHackConfig.sourceUrl;
//
//           contents.add(ScrapedContent(
//             text: _cleanText(content),
//             mediaUrls: mediaUrls,
//             hashtags: tags,
//             sourceUrl: fullUrl,
//             metadata: {
//               'rank': rank,
//               'title': title,
//               'category': category,
//               'publishDate': date,
//             },
//           ));
//         } catch (e) {
//           print('Error processing article: $e');
//           continue;
//         }
//       }
//
//       return contents;
//     } catch (e) {
//       print('Error scraping anime hack: $e');
//       rethrow;
//     }
//   }
//
//   String _cleanText(String text) {
//     if (text.isEmpty) return '';
//
//     final cleaned = text
//         .trim()
//         .replaceAll(RegExp(r'\s+'), ' ')
//         .replaceAll(RegExp(r'[\n\r]+'), '\n');
//
//     return cleaned.length > AnimeHackScrapingConfig.maxContentLength
//         ? '${cleaned.substring(0, AnimeHackScrapingConfig.maxContentLength)}...'
//         : cleaned;
//   }
// }