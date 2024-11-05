import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

class PaymentScreen extends StatefulWidget {
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late ConfettiController _confettiController;
  bool _hasActiveSubscription = false;
  bool _isRestoring = false;
  bool _isPurchasing = false;
  List<ProductDetails> _products = [];
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  final Map<String, dynamic> _plan = {
    'title': 'ベーシック',
    'price': '¥300',
    'period': '月額',
    'features': [
      {
        'icon': Icons.block,
        'title': '広告非表示',
        'description': '快適な操作環境で利用できます',
      }
    ],
    'color': Colors.blue,
    'productId': 'com.japananimemaps.application.autoSubscription.basic'
  };

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: Duration(seconds: 5));

    final Stream<List<PurchaseDetails>> purchaseUpdated =
        InAppPurchase.instance.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        print('Error: $error');
      },
    );

    _initStoreInfo();
  }

  Future<void> _initStoreInfo() async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      setState(() {
        _products = [];
        _isPurchasing = false;
        _isRestoring = false;
      });
      return;
    }

    // iOSの場合、トランザクションの監視を開始
    if (Platform.isIOS) {
      try {
        // 既存のトランザクションをチェック
        final paymentWrapper = SKPaymentQueueWrapper();
        final transactions = await paymentWrapper.transactions();

        for (final transaction in transactions) {
          if (transaction.transactionState ==
                  SKPaymentTransactionStateWrapper.purchased ||
              transaction.transactionState ==
                  SKPaymentTransactionStateWrapper.restored) {
            await _updateUserSubscriptionStatus(true);
            await paymentWrapper.finishTransaction(transaction);
          }
        }
      } catch (e) {
        print('Error checking iOS transactions: $e');
      }
    }

    try {
      final ProductDetailsResponse response = await InAppPurchase.instance
          .queryProductDetails({_plan['productId']});

      if (response.notFoundIDs.isNotEmpty) {
        print('Products not found: ${response.notFoundIDs}');
      }

      setState(() {
        _products = response.productDetails;
      });

      await _checkExistingPurchases();
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  Future<void> _checkExistingPurchases() async {
    if (Platform.isIOS) {
      try {
        final paymentWrapper = SKPaymentQueueWrapper();
        final transactions = await paymentWrapper.transactions();

        for (final transaction in transactions) {
          if (transaction.transactionState ==
                  SKPaymentTransactionStateWrapper.purchased ||
              transaction.transactionState ==
                  SKPaymentTransactionStateWrapper.restored) {
            await _updateUserSubscriptionStatus(true);
            await paymentWrapper.finishTransaction(transaction);
            break;
          }
        }
      } catch (e) {
        print('Error checking iOS purchases: $e');
      }
    }
  }

  Future<void> _updateUserSubscriptionStatus(bool isSubscribed) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'subscriptionPlan': isSubscribed ? 'basic' : null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        setState(() {
          _hasActiveSubscription = isSubscribed;
        });
      }
    } catch (e) {
      print('Error updating subscription status: $e');
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      await _updateUserSubscriptionStatus(true);
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        _confettiController.play();
      }
    }

    if (purchaseDetails.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchaseDetails);
    }

    setState(() {
      _isPurchasing = false;
      _isRestoring = false;
    });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        setState(() {
          _isPurchasing = true;
        });
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _handleError(purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _verifyPurchase(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    });
  }

  void _handleError(IAPError error) {
    setState(() {
      _isPurchasing = false;
      _isRestoring = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('エラーが発生しました: ${error.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isRestoring = true;
    });

    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('購入情報の復元に失敗しました')),
      );
      setState(() {
        _isRestoring = false;
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _onPurchase() async {
    if (_hasActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('既にサブスクリプションに加入しています')),
      );
      return;
    }

    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('現在商品を利用できません')),
      );
      return;
    }

    setState(() {
      _isPurchasing = true;
    });

    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: _products.first,
      );

      await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      setState(() {
        _isPurchasing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('購入処理に失敗しました')),
      );
    }
  }

  void _showPurchaseBottomSheet() {
    if (_hasActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('既にサブスクリプションに加入しています')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '有料プラン',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'ベーシックプラン',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 24),
            ..._plan['features']
                .map<Widget>((feature) => Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: Icon(
                              feature['icon'],
                              size: 28,
                              color: _plan['color'],
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  feature['title'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
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
            Spacer(),
            ElevatedButton(
              onPressed: _isPurchasing ? null : _onPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00008b),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                minimumSize: Size(double.infinity, 0),
              ),
              child: Text(
                _isPurchasing ? '処理中...' : '購入する',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 12),
            TextButton(
              onPressed: _isRestoring ? null : _restorePurchases,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 8),
                minimumSize: Size(double.infinity, 0),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Color(0xFF00008b)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
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
          constraints: BoxConstraints(maxWidth: 600),
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
                child: SafeArea(
                  child: ListView(
                    padding: EdgeInsets.all(16),
                    children: [
                      InkWell(
                        onTap: _showPurchaseBottomSheet,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
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
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.star, color: _plan['color']),
                                        SizedBox(width: 8),
                                        Text(
                                          _plan['title'],
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          _products.isNotEmpty
                                              ? _products.first.price
                                              : _plan['price'],
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: _plan['color'],
                                          ),
                                        ),
                                        Text(
                                          ' / ${_plan['period']}',
                                          style: TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    ..._plan['features']
                                        .map<Widget>(
                                          (feature) => Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  color: _plan['color'],
                                                  size: 20,
                                                ),
                                                SizedBox(width: 8),
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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
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
                    ],
                  ),
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
                  child: Center(
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

// StoreKit デリゲートクラスの実装
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
