// lib/configs/anime_hack_config.dart
import 'package:parts/post_page/service/auto_post_types.dart';

final animeHackConfig = AutoPostConfig(
  sourceUrl: 'https://anime.eiga.com/ranking/article/',
  selector: '.rankingLowContainer .rankingList',
  interval: const Duration(hours: 1),
  minInterval: const Duration(minutes: 30),
  maxRetries: 3,
  headers: {
    'User-Agent': 'Mozilla/5.0 (compatible; AnimeNewsBot/1.0)',
    'Accept-Language': 'ja',
  },
  isActive: true,
);

class AnimeHackScrapingConfig {
  static const selectors = {
    'rank': '.iconRank',
    'title': 'a.rankingTtl',
    'date': '.newsDate',
    'category': '.personCateTag img',
    'content': '.personRankingTopL p',
    'tags': '.tagList a',
    'thumbnail': '.personRankingTopR img',
  };

  static const maxContentLength = 1000;
  static const maxTags = 5;
  static const requiredFields = ['title', 'content'];
}