// AdManager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  // デバッグモードとリリースモードで広告ユニットIDを切り替え
  static String get _rewardedAdUnitId {
    if (kDebugMode) {
      // デバッグモード時はテスト広告ID
      print('AdManager: Using TEST ad unit ID');
      return 'ca-app-pub-3940256099942544/5224354917'; // テスト用リワード広告ID
    } else {
      // リリースモード時は本番広告ID
      print('AdManager: Using PRODUCTION ad unit ID');
      return 'ca-app-pub-1580421227117187/8650426844';
    }
  }

  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdLoaded = false;
  static bool _isInitialized = false;
  static bool _isLoading = false;

  static List<Function(bool)> _adStatusListeners = [];

  static void addAdStatusListener(Function(bool) listener) {
    _adStatusListeners.add(listener);
    print('AdManager: Added listener, total: ${_adStatusListeners.length}');

    // 既に広告がロードされている場合は即座に通知
    if (_isRewardedAdLoaded) {
      print('AdManager: Immediately notifying new listener with current status: $_isRewardedAdLoaded');
      try {
        Future.microtask(() => listener(_isRewardedAdLoaded && _rewardedAd != null));
      } catch (e) {
        print('AdManager: Error notifying new listener: $e');
      }
    }
  }

  static void removeAdStatusListener(Function(bool) listener) {
    _adStatusListeners.remove(listener);
    print('AdManager: Removed listener, remaining: ${_adStatusListeners.length}');
  }

  static void _notifyListeners() {
    final bool adStatus = _isRewardedAdLoaded && _rewardedAd != null;
    print('AdManager: Notifying ${_adStatusListeners.length} listeners with status: $adStatus');
    print('AdManager: _isRewardedAdLoaded: $_isRewardedAdLoaded, _rewardedAd != null: ${_rewardedAd != null}');

    // リスナーのコピーを作成して操作
    final listeners = List<Function(bool)>.from(_adStatusListeners);

    for (var listener in listeners) {
      try {
        // 非同期でリスナーを呼び出してUIスレッドの競合を避ける
        Future.microtask(() {
          print('AdManager: Calling listener with status: $adStatus');
          listener(adStatus);
        });
      } catch (e) {
        print('AdManager: Error notifying listener: $e');
        // 問題のあるリスナーは削除
        _adStatusListeners.remove(listener);
      }
    }
  }

  // Initialize the AdMob SDK
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('AdManager: Already initialized, skipping...');
      return;
    }

    print('AdManager: Starting initialization...');
    print('AdManager: Flutter debug mode: $kDebugMode');

    try {
      // デバッグモードの場合はテスト機器IDを設定
      if (kDebugMode) {
        print('AdManager: Debug mode - configuring test devices');
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: ['kGADSimulatorID'], // iOS Simulator
            tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
          ),
        );
        print('AdManager: Test device configuration completed');
      } else {
        print('AdManager: Release mode - using production configuration');
      }

      print('AdManager: Initializing MobileAds SDK...');
      final InitializationStatus initStatus = await MobileAds.instance.initialize();

      print('AdManager: MobileAds SDK initialized successfully');
      print('AdManager: Initialization status: ${initStatus.adapterStatuses}');

      _isInitialized = true;

      print('AdManager: Ad unit ID to be used: ${_rewardedAdUnitId}');

      // 初期化完了後に広告をロード
      await _loadRewardedAd();

    } catch (e) {
      print('AdManager: Error initializing MobileAds: $e');
      print('AdManager: Stack trace: ${StackTrace.current}');
    }
  }

  static Future<void> _loadRewardedAd() async {
    if (_isLoading) {
      print('AdManager: Already loading an ad, skipping...');
      return;
    }

    if (!_isInitialized) {
      print('AdManager: SDK not initialized, cannot load ad');
      return;
    }

    _isLoading = true;
    print('AdManager: Starting to load rewarded ad...');
    print('AdManager: Ad unit ID: ${_rewardedAdUnitId}');
    print('AdManager: Debug mode: $kDebugMode');

    // 既存の広告を破棄
    if (_rewardedAd != null) {
      print('AdManager: Disposing existing ad before loading new one');
      _rewardedAd!.dispose();
      _rewardedAd = null;
      _isRewardedAdLoaded = false;
    }

    try {
      print('AdManager: Calling RewardedAd.load()...');

      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            print('AdManager: ✅ Rewarded ad loaded successfully!');
            print('AdManager: Ad response info: ${ad.responseInfo}');

            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
            _isLoading = false;

            print('AdManager: Setting up full screen content callback...');

            // Set full-screen callback
            _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (RewardedAd ad) {
                print('AdManager: 📺 Ad showed full screen content');
              },
              onAdDismissedFullScreenContent: (RewardedAd ad) {
                print('AdManager: 🚪 Ad dismissed full screen content');
                _isRewardedAdLoaded = false;
                ad.dispose();
                _rewardedAd = null;
                _notifyListeners();

                // 次の広告をプリロード
                print('AdManager: Loading next ad...');
                Future.delayed(Duration(seconds: 1), () {
                  _loadRewardedAd();
                });
              },
              onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
                print('AdManager: ❌ Ad failed to show full screen content');
                print('AdManager: Error code: ${error.code}');
                print('AdManager: Error message: ${error.message}');
                print('AdManager: Error domain: ${error.domain}');

                _isRewardedAdLoaded = false;
                ad.dispose();
                _rewardedAd = null;
                _notifyListeners();

                // 再試行
                Future.delayed(Duration(seconds: 5), () {
                  _loadRewardedAd();
                });
              },
              onAdImpression: (RewardedAd ad) {
                print('AdManager: 👁️ Ad impression recorded');
              },
            );

            print('AdManager: Notifying listeners of successful load...');
            _notifyListeners();
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('AdManager: ❌ Rewarded ad failed to load');
            print('AdManager: Error code: ${error.code}');
            print('AdManager: Error message: ${error.message}');
            print('AdManager: Error domain: ${error.domain}');
            print('AdManager: Error response info: ${error.responseInfo}');

            _isRewardedAdLoaded = false;
            _rewardedAd = null;
            _isLoading = false;
            _notifyListeners();

            // エラーコードに応じたリトライ戦略
            int retryDelay = 10;
            switch (error.code) {
              case 0: // ERROR_CODE_INTERNAL_ERROR
                retryDelay = 30;
                break;
              case 1: // ERROR_CODE_INVALID_REQUEST
                retryDelay = 60;
                print('AdManager: Invalid request - check ad unit ID and configuration');
                break;
              case 2: // ERROR_CODE_NETWORK_ERROR
                retryDelay = 15;
                break;
              case 3: // ERROR_CODE_NO_FILL
                retryDelay = 20;
                print('AdManager: No ad inventory available');
                break;
              default:
                retryDelay = 10;
            }

            print('AdManager: Retrying ad load in $retryDelay seconds...');
            Future.delayed(Duration(seconds: retryDelay), () {
              if (!_isRewardedAdLoaded) {
                _loadRewardedAd();
              }
            });
          },
        ),
      );

      print('AdManager: RewardedAd.load() call completed, waiting for callback...');

    } catch (e) {
      print('AdManager: ❌ Exception during ad loading: $e');
      print('AdManager: Stack trace: ${StackTrace.current}');
      _isLoading = false;
      _isRewardedAdLoaded = false;
      _rewardedAd = null;

      // 例外の場合も再試行
      Future.delayed(Duration(seconds: 10), () {
        _loadRewardedAd();
      });
    }
  }

  static Future<bool> showRewardedAd(Function onRewarded) async {
    print('AdManager: 🎬 Attempting to show rewarded ad...');
    print('AdManager: _isRewardedAdLoaded: $_isRewardedAdLoaded');
    print('AdManager: _rewardedAd != null: ${_rewardedAd != null}');

    if (!_isRewardedAdLoaded || _rewardedAd == null) {
      print('AdManager: ❌ No ad available to show');
      print('AdManager: isLoaded: $_isRewardedAdLoaded, ad exists: ${_rewardedAd != null}');

      // 広告が利用できない場合は新しい広告をロード
      print('AdManager: Attempting to load new ad...');
      _loadRewardedAd();
      return false;
    }

    print('AdManager: 🚀 Showing rewarded ad...');

    try {
      // 広告表示前にコールバックを設定し直す
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (RewardedAd ad) {
          print('AdManager: 📺 Ad showed full screen content - SUCCESS!');
        },
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          print('AdManager: 🚪 Ad dismissed full screen content');
          _isRewardedAdLoaded = false;
          ad.dispose();
          _rewardedAd = null;
          _notifyListeners();

          // 次の広告をプリロード
          print('AdManager: Loading next ad...');
          Future.delayed(Duration(seconds: 1), () {
            _loadRewardedAd();
          });
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          print('AdManager: ❌ Ad failed to show full screen content');
          print('AdManager: Error code: ${error.code}');
          print('AdManager: Error message: ${error.message}');
          print('AdManager: Error domain: ${error.domain}');

          _isRewardedAdLoaded = false;
          ad.dispose();
          _rewardedAd = null;
          _notifyListeners();

          // 再試行
          Future.delayed(Duration(seconds: 5), () {
            _loadRewardedAd();
          });
        },
        onAdImpression: (RewardedAd ad) {
          print('AdManager: 👁️ Ad impression recorded - Ad is being displayed!');
        },
      );

      // 広告を表示（同期的に実行）
      _rewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            print('AdManager: 🎁 User earned reward!');
            print('AdManager: Reward type: ${reward.type}');
            print('AdManager: Reward amount: ${reward.amount}');

            try {
              print('AdManager: 🔄 Executing reward callback...');
              onRewarded();
              print('AdManager: ✅ Reward callback executed successfully');
            } catch (e) {
              print('AdManager: ❌ Error in reward callback: $e');
              print('AdManager: Stack trace: ${StackTrace.current}');
            }
          }
      );

      print('AdManager: ✅ Ad.show() called successfully');
      return true;

    } catch (e) {
      print('AdManager: ❌ Exception during ad show: $e');
      print('AdManager: Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  static bool isRewardedAdAvailable() {
    bool available = _isRewardedAdLoaded && _rewardedAd != null;
    print('AdManager: 🔍 Checking ad availability: $available');
    print('AdManager: Details - loaded: $_isRewardedAdLoaded, exists: ${_rewardedAd != null}, loading: $_isLoading');
    return available;
  }

  // 手動で広告を再ロードするメソッドを追加
  static Future<void> reloadAd() async {
    print('AdManager: 🔄 Manual ad reload requested');
    if (_rewardedAd != null) {
      print('AdManager: Disposing existing ad for manual reload');
      _rewardedAd!.dispose();
      _rewardedAd = null;
      _isRewardedAdLoaded = false;
    }
    _isLoading = false;
    await _loadRewardedAd();
  }

  // デバッグ情報を取得するメソッドを追加
  static Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'isRewardedAdLoaded': _isRewardedAdLoaded,
      'isLoading': _isLoading,
      'rewardedAdExists': _rewardedAd != null,
      'adUnitId': _rewardedAdUnitId,
      'debugMode': kDebugMode,
      'listenersCount': _adStatusListeners.length,
    };
  }

  static void dispose() {
    print('AdManager: 🗑️ Disposing resources');
    print('AdManager: Current state - loaded: $_isRewardedAdLoaded, exists: ${_rewardedAd != null}');

    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdLoaded = false;
    _isLoading = false;
    _adStatusListeners.clear();

    print('AdManager: Dispose completed');
  }
}