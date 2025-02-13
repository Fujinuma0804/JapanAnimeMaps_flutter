// lib/models/scraped_content.dart
// lib/models/scraped_content.dart

class ScrapedContent {
  final String text;
  final List<String> mediaUrls;
  final List<String> hashtags;
  final String sourceUrl;
  final Map<String, String> metadata;

  ScrapedContent({
    required this.text,
    required this.mediaUrls,
    required this.hashtags,
    required this.sourceUrl,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'mediaUrls': mediaUrls,
    'hashtags': hashtags,
    'sourceUrl': sourceUrl,
    'metadata': metadata,
  };
}

// lib/models/auto_post_config.dart
class AutoPostConfig {
  final String sourceUrl;
  final String selector;
  final Duration interval;
  final Duration minInterval;
  final int maxRetries;
  final bool isActive;
  final Map<String, String> headers;

  AutoPostConfig({
    required this.sourceUrl,
    required this.selector,
    required this.interval,
    this.minInterval = const Duration(minutes: 5),
    this.maxRetries = 3,
    this.isActive = true,
    this.headers = const {},
  });

  Map<String, dynamic> toJson() => {
    'sourceUrl': sourceUrl,
    'selector': selector,
    'interval': interval.inSeconds,
    'minInterval': minInterval.inSeconds,
    'maxRetries': maxRetries,
    'isActive': isActive,
    'headers': headers,
  };

  factory AutoPostConfig.fromJson(Map<String, dynamic> json) {
    return AutoPostConfig(
      sourceUrl: json['sourceUrl'] as String,
      selector: json['selector'] as String,
      interval: Duration(seconds: json['interval'] as int),
      minInterval: Duration(seconds: json['minInterval'] as int),
      maxRetries: json['maxRetries'] as int,
      isActive: json['isActive'] as bool,
      headers: Map<String, String>.from(json['headers'] as Map),
    );
  }
}