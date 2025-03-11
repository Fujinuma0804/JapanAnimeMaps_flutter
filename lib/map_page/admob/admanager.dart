// AdManager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  // iOSテスト広告IDに変更
  static const String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313'; // iOSテスト広告ID

  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdLoaded = false;

  static List<Function(bool)> _adStatusListeners = [];
  static void addAdStatusListener(Function(bool) listener) {
    _adStatusListeners.add(listener);
  }

  static void removeAdStatusListener(Function(bool) listener) {
    _adStatusListeners.remove(listener);
    print('AdManager: Removed listener, remaining: ${_adStatusListeners.length}');
  }

  static void _notifyListeners() {
    print('AdManager: Notifying ${_adStatusListeners.length} listeners');
    // リスナーのコピーを作成して操作
    final listeners = List<Function(bool)>.from(_adStatusListeners);
    for (var listener in listeners) {
      try {
        listener(_isRewardedAdLoaded && _rewardedAd != null);
      } catch (e) {
        print('AdManager: Error notifying listener: $e');
        // 問題のあるリスナーは削除
        _adStatusListeners.remove(listener);
      }
    }
  }

  // Initialize the AdMob SDK
  static Future<void> initialize() async {
    print('AdManager: Initializing...');
    try {
      // テスト機器IDを追加（オプション）
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: ['kGADSimulatorID']),
      );

      await MobileAds.instance.initialize();
      print('AdManager: MobileAds initialized successfully');
      _loadRewardedAd();
    } catch (e) {
      print('AdManager: Error initializing MobileAds: $e');
    }
  }

  // 以下の部分は変更なし
  static void _loadRewardedAd() {
    print('AdManager: Loading rewarded ad...');
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('AdManager: Rewarded ad loaded successfully');
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          _notifyListeners();

          // Set full-screen callback
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              print('AdManager: Ad dismissed full screen content');
              _isRewardedAdLoaded = false;
              ad.dispose();
              _notifyListeners();
              _loadRewardedAd(); // Load a new ad for next time
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              print('AdManager: Ad failed to show full screen content: ${error.message}');
              _isRewardedAdLoaded = false;
              ad.dispose();
              _notifyListeners();
              _loadRewardedAd(); // Try to load a new ad
            },
            onAdShowedFullScreenContent: (RewardedAd ad) {
              print('AdManager: Ad showed full screen content');
            },
            onAdImpression: (RewardedAd ad) {
              print('AdManager: Ad impression recorded');
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('AdManager: Rewarded ad failed to load: ${error.message} (code: ${error.code})');
          _isRewardedAdLoaded = false;
          _notifyListeners();

          Future.delayed(Duration(seconds: 30), () {
            if (!_isRewardedAdLoaded) {
              _loadRewardedAd();
            }
          });
        },
      ),
    );
  }

  static Future<bool> showRewardedAd(Function onRewarded) async {
    print('AdManager: Attempting to show rewarded ad...');
    if (!_isRewardedAdLoaded || _rewardedAd == null) {
      print('AdManager: No ad available to show. isLoaded: $_isRewardedAdLoaded, ad: ${_rewardedAd != null}');
      _loadRewardedAd(); // Try to load an ad if it's not available
      return false;
    }

    final Completer<bool> completer = Completer<bool>();

    try {
      print('AdManager: Showing rewarded ad...');
      _rewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            print('AdManager: User earned reward: ${reward.amount} ${reward.type}');
            // User earned a reward, provide the reward
            onRewarded();
            completer.complete(true);
          }
      );
    } catch (e) {
      print('AdManager: Error showing rewarded ad: $e');
      completer.complete(false);
    }

    return completer.future;
  }

  static bool isRewardedAdAvailable() {
    print('AdManager: Checking if ad is available: $_isRewardedAdLoaded && ${_rewardedAd != null}');
    return _isRewardedAdLoaded && _rewardedAd != null;
  }

  static void dispose() {
    print('AdManager: Disposing resources');
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}