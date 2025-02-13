// models/scraped_data.dart
class ScrapedData {
  final String text;
  final List<String> imageUrls;
  final List<String> hashtags;
  final String sourceUrl;
  final DateTime scrapedAt;

  ScrapedData({
    required this.text,
    required this.imageUrls,
    required this.hashtags,
    required this.sourceUrl,
    required this.scrapedAt,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'imageUrls': imageUrls,
    'hashtags': hashtags,
    'sourceUrl': sourceUrl,
    'scrapedAt': scrapedAt.toIso8601String(),
  };

  factory ScrapedData.fromJson(Map<String, dynamic> json) {
    return ScrapedData(
      text: json['text'] as String,
      imageUrls: List<String>.from(json['imageUrls']),
      hashtags: List<String>.from(json['hashtags']),
      sourceUrl: json['sourceUrl'] as String,
      scrapedAt: DateTime.parse(json['scrapedAt']),
    );
  }
}