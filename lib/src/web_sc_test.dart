import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;

class AnimeNewsScraper {
  static const String _url =
      'https://prtimes.jp/main/action.php?run=html&page=searchkey&search_word=%E3%82%A2%E3%83%8B%E3%83%A1';

  Future<List<String>> scrapeAnimeNews() async {
    final target = Uri.parse(_url);

    try {
      final response = await http.get(target);

      if (response.statusCode != 200) {
        throw Exception('ERROR: ${response.statusCode}');
      }

      final document = parse(response.body);
      return document.querySelectorAll('h2').map((v) => v.text).toList();
    } catch (e) {
      print('Error occurred while scraping: $e');
      return [];
    }
  }
}
