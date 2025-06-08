import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late ConfettiController _confettiController;
  bool _hasActiveSubscription = false;
  bool _isRestoring = false;
  bool _isPurchasing = false;
  bool _isInitialized = false;
  String? _initError;
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  CustomerInfo? _customerInfo;
  String _userLanguage = 'English';
  late User _user;
  late Stream<DocumentSnapshot> _userStream;

  // RevenueCatダッシュボードの設定に合わせた識別子
  static const String _productId = 'jam_300_1m_1w0';
  static const String _entitlementId = 'jam_300_1m_1w0';

  // 広告ユニットID
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy' // Androidの広告ユニットID
      : 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy'; // iOSの広告ユニットID

  // 多言語対応テキスト
  Map<String, Map<String, String>> get _texts => {
    'Japanese': {
      'title': 'プレミアム会員になる',
      'premiumPlan': '有料プラン',
      'basicPlan': 'ベーシックプラン',
      'price': '¥300',
      'period': '月額',
      'adFreeTitle': '広告非表示',
      'adFreeDesc': '快適な操作環境で利用できます',
      'allFeaturesTitle': '全ての機能を利用可能',
      'allFeaturesDesc': 'プレミアム機能をご利用いただけます',
      'purchase': '購入する',
      'processing': '処理中...',
      'restore': '以前の購入を復元する',
      'restoring': '復元中...',
      'active': '利用中',
      'thankYou': 'ご購入ありがとうございます！',
      'alreadySubscribed': '既にサブスクリプションに加入しています',
      'purchaseFailed': '購入処理に失敗しました',
      'purchaseCancelled': '購入がキャンセルされました',
      'paymentPending': '決済処理が保留中です',
      'storeProblem': 'ストアとの通信に問題が発生しました',
      'restored': '購入情報を復元しました',
      'noValidPurchase': '有効な購入情報が見つかりませんでした',
      'restoreFailed': '購入情報の復元に失敗しました',
      'initializing': 'サービスの初期化中です。しばらくお待ちください。',
      'initError': '初期化エラー',
      'retry': '再試行',
    },
    'English': {
      'title': 'Become a Premium Member',
      'premiumPlan': 'Premium Plan',
      'basicPlan': 'Basic Plan',
      'price': '¥300',
      'period': 'Monthly',
      'adFreeTitle': 'Ad-Free Experience',
      'adFreeDesc': 'Enjoy a comfortable user experience without interruptions',
      'allFeaturesTitle': 'Access All Features',
      'allFeaturesDesc': 'Unlock all premium features',
      'purchase': 'Purchase',
      'processing': 'Processing...',
      'restore': 'Restore Previous Purchases',
      'restoring': 'Restoring...',
      'active': 'Active',
      'thankYou': 'Thank you for your purchase!',
      'alreadySubscribed': 'You already have an active subscription',
      'purchaseFailed': 'Purchase failed',
      'purchaseCancelled': 'Purchase was cancelled',
      'paymentPending': 'Payment is pending',
      'storeProblem': 'Store communication error occurred',
      'restored': 'Purchase information restored',
      'noValidPurchase': 'No valid purchase information found',
      'restoreFailed': 'Failed to restore purchase information',
      'initializing': 'Service is initializing. Please wait.',
      'initError': 'Initialization Error',
      'retry': 'Retry',
    },
  };

  Map<String, dynamic> _getPlan() {
    print('PaymentScreen - _getPlan() called with language: $_userLanguage');
    final plan = {
      'title': _getText('basicPlan'),
      'price': _getText('price'),
      'period': _getText('period'),
      'features': [
        {
          'icon': Icons.block,
          'title': _getText('adFreeTitle'),
          'description': _getText('adFreeDesc'),
        },
        {
          'icon': Icons.map,
          'title': _getText('allFeaturesTitle'),
          'description': _getText('allFeaturesDesc'),
        }
      ],
      'color': Colors.blue,
      'entitlementId': 'basic'
    };
    print('PaymentScreen - _getPlan() result: ${plan['title']}');
    return plan;
  }

  String _getText(String key) {
    final result = _texts[_userLanguage]?[key] ?? _texts['English']![key]!;
    print('PaymentScreen - _getText($key) with language $_userLanguage = $result');
    return result;
  }

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));
    _getUser();
    _initializeServices();
    _initBannerAd();
    _setupUserStream();
  }

  Future<void> _getUser() async {
    _user = FirebaseAuth.instance.currentUser!;
  }

  void _setupUserStream() {
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .snapshots();

    _userStream.listen((DocumentSnapshot snapshot) {
      print('PaymentScreen - Stream listener called');
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final language = data['language'] ?? 'English';
        print('PaymentScreen - Document exists: ${snapshot.exists}');
        print('PaymentScreen - Document data: $data');
        print('PaymentScreen - Language from Firestore: $language');
        print('PaymentScreen - Before setState _userLanguage: $_userLanguage');

        setState(() {
          _userLanguage = language;
        });

        print('PaymentScreen - After setState _userLanguage: $_userLanguage');
      } else {
        print('PaymentScreen - Document does not exist');
      }
    });
  }

  Future<void> _initializeServices() async {
    try {
      // サブスクリプション状態の確認
      final customerInfo = await Purchases.getCustomerInfo();
      _customerInfo = customerInfo;

      setState(() {
        _hasActiveSubscription =
            customerInfo.entitlements.active.containsKey(_entitlementId);
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _initError = e.toString();
        _isInitialized = true;
      });
      print('Initialization error: $e');
    }
  }

  void _initBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('Ad load failed (code=${error.code} message=${error.message})');
        },
      ),
    );

    _bannerAd?.load();
  }

  Future<void> _updateFirebaseSubscriptionStatus(bool isSubscribed) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isSubscribed': isSubscribed,
          'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
          'subscriptionPlan': isSubscribed ? 'basic' : null,
          'purchaseTimestamp':
          isSubscribed ? FieldValue.serverTimestamp() : null,
        }, SetOptions(merge: true));
      } catch (e) {
        print('Error updating Firebase subscription status: $e');
        throw Exception('Failed to update subscription status in Firebase');
      }
    }
  }

  Future<void> _onPurchase() async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getText('initializing'))),
      );
      return;
    }

    setState(() {
      _isPurchasing = true;
    });

    try {
      final purchaseResult = await Purchases.purchaseProduct(_productId);

      final isSubscribed =
      purchaseResult.entitlements.active.containsKey(_entitlementId);

      await _updateFirebaseSubscriptionStatus(isSubscribed);

      setState(() {
        _hasActiveSubscription = isSubscribed;
        _customerInfo = purchaseResult;
      });

      if (isSubscribed && mounted) {
        _confettiController.play();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getText('thankYou'))),
        );
      }
    } on PurchasesErrorCode catch (e) {
      print('RevenueCat error: $e');
      String message = _getText('purchaseFailed');

      if (e == PurchasesErrorCode.purchaseCancelledError) {
        message = _getText('purchaseCancelled');
      } else if (e == PurchasesErrorCode.paymentPendingError) {
        message = _getText('paymentPending');
      } else if (e == PurchasesErrorCode.storeProblemError) {
        message = _getText('storeProblem');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isRestoring = true;
    });

    try {
      final customerInfo = await Purchases.restorePurchases();

      final isSubscribed =
      customerInfo.entitlements.active.containsKey(_entitlementId);

      await _updateFirebaseSubscriptionStatus(isSubscribed);

      setState(() {
        _hasActiveSubscription = isSubscribed;
        _customerInfo = customerInfo;
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSubscribed ? _getText('restored') : _getText('noValidPurchase')),
          ),
        );
      }
    } catch (e) {
      print('Error restoring purchases: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getText('restoreFailed'))),
        );
      }
    } finally {
      setState(() {
        _isRestoring = false;
      });
    }
  }

  void _showPurchaseBottomSheet() {
    if (_hasActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getText('alreadySubscribed'))),
      );
      return;
    }

    final plan = _getPlan();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _getText('premiumPlan'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _getText('basicPlan'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            ...plan['features']
                .map<Widget>((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    feature['icon'],
                    size: 28,
                    color: plan['color'],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          feature['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ))
                .toList(),
            const Spacer(),
            ElevatedButton(
              onPressed: _isPurchasing ? null : _onPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00008b),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                minimumSize: const Size(double.infinity, 0),
              ),
              child: Text(
                _isPurchasing ? _getText('processing') : _getText('purchase'),
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isRestoring ? null : _restorePurchases,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: const Size(double.infinity, 0),
              ),
              child: Text(
                _isRestoring ? _getText('restoring') : _getText('restore'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData != null) {
            final language = userData['language'] ?? 'English';
            print('PaymentScreen - StreamBuilder language: $language');
            print('PaymentScreen - StreamBuilder before update _userLanguage: $_userLanguage');
            _userLanguage = language;
            print('PaymentScreen - StreamBuilder after update _userLanguage: $_userLanguage');
          }
        }

        if (!_isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_initError != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_getText('initError')),
                  Text(_initError!, style: const TextStyle(color: Colors.red)),
                  ElevatedButton(
                    onPressed: _initializeServices,
                    child: Text(_getText('retry')),
                  ),
                ],
              ),
            ),
          );
        }

        final plan = _getPlan();
        print('PaymentScreen - build() method plan title: ${plan['title']}');
        print('PaymentScreen - build() method current language: $_userLanguage');

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF00008b)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getText('title'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // デバッグ情報を表示
                Text(
                  'Debug: $_userLanguage',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
          ),
          extendBodyBehindAppBar: true,
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue[100]!, Colors.purple[100]!],
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: SafeArea(
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                InkWell(
                                  onTap: _showPurchaseBottomSheet,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.star,
                                                      color: plan['color']),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    plan['title'],
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Text(
                                                    _customerInfo
                                                        ?.activeSubscriptions
                                                        .isNotEmpty ==
                                                        true
                                                        ? _customerInfo!
                                                        .activeSubscriptions
                                                        .first
                                                        : plan['price'],
                                                    style: TextStyle(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.bold,
                                                      color: plan['color'],
                                                    ),
                                                  ),
                                                  Text(
                                                    ' / ${plan['period']}',
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              ...plan['features']
                                                  .map<Widget>(
                                                    (feature) => Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 4),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.check_circle,
                                                        color: plan['color'],
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(feature['title']),
                                                    ],
                                                  ),
                                                ),
                                              )
                                                  .toList(),
                                            ],
                                          ),
                                        ),
                                        if (_hasActiveSubscription)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius:
                                                BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                _getText('active'),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20.0),
                                if (_isAdLoaded && !_hasActiveSubscription)
                                  SizedBox(
                                    width: _bannerAd!.size.width.toDouble(),
                                    height: _bannerAd!.size.height.toDouble(),
                                    child: AdWidget(ad: _bannerAd!),
                                  )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirection: pi / 2,
                      maxBlastForce: 5,
                      minBlastForce: 2,
                      emissionFrequency: 0.05,
                      numberOfParticles: 50,
                      gravity: 0.1,
                    ),
                  ),
                  if (_isPurchasing || _isRestoring)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}