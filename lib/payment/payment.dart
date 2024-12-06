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

  // RevenueCatダッシュボードの設定に合わせた識別子
  static const String _productId = 'jam_300_1m_1w0';
  static const String _entitlementId = 'jam_300_1m_1w0';

  // 広告ユニットID
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy' // Androidの広告ユニットID
      : 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy'; // iOSの広告ユニットID

  final Map<String, dynamic> _plan = {
    'title': 'ベーシック',
    'price': '¥300',
    'period': '月額',
    'features': [
      {
        'icon': Icons.block,
        'title': '広告非表示',
        'description': '快適な操作環境で利用できます',
      },
      {
        'icon': Icons.map,
        'title': '全ての機能を利用可能',
        'description': 'プレミアム機能をご利用いただけます',
      }
    ],
    'color': Colors.blue,
    'entitlementId': 'basic'
  };

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));
    _initializeServices();
    _initBannerAd();
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
        const SnackBar(content: Text('サービスの初期化中です。しばらくお待ちください。')),
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
          const SnackBar(content: Text('ご購入ありがとうございます！')),
        );
      }
    } on PurchasesErrorCode catch (e) {
      print('RevenueCat error: $e');
      String message = '購入処理に失敗しました';

      if (e == PurchasesErrorCode.purchaseCancelledError) {
        message = '購入がキャンセルされました';
      } else if (e == PurchasesErrorCode.paymentPendingError) {
        message = '決済処理が保留中です';
      } else if (e == PurchasesErrorCode.storeProblemError) {
        message = 'ストアとの通信に問題が発生しました';
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
            content: Text(isSubscribed ? '購入情報を復元しました' : '有効な購入情報が見つかりませんでした'),
          ),
        );
      }
    } catch (e) {
      print('Error restoring purchases: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('購入情報の復元に失敗しました')),
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
        const SnackBar(content: Text('既にサブスクリプションに加入しています')),
      );
      return;
    }

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
            const Text(
              '有料プラン',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ベーシックプラン',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            ..._plan['features']
                .map<Widget>((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            feature['icon'],
                            size: 28,
                            color: _plan['color'],
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
                _isPurchasing ? '処理中...' : '購入する',
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
                _isRestoring ? '復元中...' : '以前の購入を復元する',
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
              const Text('初期化エラー'),
              Text(_initError!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _initializeServices,
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF00008b)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'プレミアム会員になる',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
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
                                                  color: _plan['color']),
                                              const SizedBox(width: 8),
                                              Text(
                                                _plan['title'],
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
                                                    : _plan['price'],
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: _plan['color'],
                                                ),
                                              ),
                                              Text(
                                                ' / ${_plan['period']}',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ..._plan['features']
                                              .map<Widget>(
                                                (feature) => Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 4),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.check_circle,
                                                        color: _plan['color'],
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
                                          child: const Text(
                                            '利用中',
                                            style: TextStyle(
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
  }
}
