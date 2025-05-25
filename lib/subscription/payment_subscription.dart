import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentSubscriptionScreen extends StatefulWidget {
  const PaymentSubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<PaymentSubscriptionScreen> createState() => _PaymentSubscriptionScreenState();
}

class _PaymentSubscriptionScreenState extends State<PaymentSubscriptionScreen> {
  // Add state variable to track selected plan
  bool _isYearlyPlanSelected = true;

  // 製品ID（これはRevenueCatの製品識別子に対応します）
  final String _yearlyProductId = 'jam_pre_3600_year';
  final String _monthlyProductId = 'jam_pre_500_month';

  // パッケージ識別子（RevenueCatで使用される実際のパッケージ識別子）
  // デバッグ出力の実際のパッケージIDに合わせる
  final String _yearlyPackageId = '\$rc_annual';  // 文字列として$を含める
  final String _monthlyPackageId = '\$rc_monthly';  // 文字列として$を含める

  bool _isLoading = false;
  String? _errorMessage;

  // 契約状態を管理する変数
  bool _hasYearlySubscription = false;
  bool _hasMonthlySubscription = false;
  bool _isCheckingSubscription = true;

  // 利用規約とプライバシーポリシーのURL
  final String _termsOfServiceUrl = 'https://animetourism.co.jp/terms.html'; // 実際のURLに変更してください
  final String _privacyPolicyUrl = 'https://animetourism.co.jp/privacy.html'; // 実際のURLに変更してください

  @override
  void initState() {
    super.initState();
    _setupPurchases();
  }

  Future<void> _setupPurchases() async {
    try {
      // まず契約状態をチェック
      await _checkCurrentSubscription();

      // RevenueCatの構成情報を出力
      final offerings = await Purchases.getOfferings();
      print('=== RevenueCat Configuration Status ===');

      // すべての利用可能なオファリングをログに記録
      print('利用可能なすべてのオファリング:');
      offerings.all.forEach((offeringId, offering) {
        print('オファリングID: $offeringId');
        print('利用可能なパッケージ:');
        for (var pkg in offering.availablePackages) {
          try {
            print('- パッケージ: ${pkg.identifier}');
            print('  プロダクト: ${pkg.storeProduct.identifier}');
            print('  価格: ${pkg.storeProduct.priceString}');
          } catch (e) {
            print('- パッケージ: ${pkg.identifier} (プロダクト情報へのアクセスエラー: $e)');
          }
        }
      });

      // 現在のオファリング情報をログに記録
      if (offerings.current != null) {
        print('\n現在のオファリング: ${offerings.current!.identifier}');
        print('利用可能なパッケージ:');
        for (var pkg in offerings.current!.availablePackages) {
          try {
            print('- パッケージ: ${pkg.identifier}');
            print('  プロダクト: ${pkg.storeProduct.identifier}');
            print('  価格: ${pkg.storeProduct.priceString}');
          } catch (e) {
            print('- パッケージ: ${pkg.identifier} (プロダクト情報へのアクセスエラー: $e)');
          }
        }
      } else {
        print('利用可能な現在のオファリングがありません');
      }

      setState(() {
        _isCheckingSubscription = false;
      });
    } catch (e) {
      // エラーハンドリング
      print('RevenueCat setup error: $e');
      setState(() {
        _isCheckingSubscription = false;
      });
    }
  }

  // 現在の契約状態をチェックする関数
  Future<void> _checkCurrentSubscription() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      print('\n=== 現在の契約状態チェック ===');
      print('ユーザーID: ${customerInfo.originalAppUserId}');
      print('アクティブなサブスクリプション: ${customerInfo.activeSubscriptions}');
      print('アクティブなエンタイトルメント: ${customerInfo.entitlements.active.keys}');

      bool hasYearly = false;
      bool hasMonthly = false;

      // アクティブなサブスクリプションをチェック
      for (String productId in customerInfo.activeSubscriptions) {
        print('アクティブなプロダクトID: $productId');

        if (productId == _yearlyProductId ||
            productId.toLowerCase().contains('year') ||
            productId.toLowerCase().contains('annual')) {
          hasYearly = true;
          print('年額プランが検出されました: $productId');
        }

        if (productId == _monthlyProductId ||
            productId.toLowerCase().contains('month')) {
          hasMonthly = true;
          print('月額プランが検出されました: $productId');
        }
      }

      // エンタイトルメントからも確認
      for (var entry in customerInfo.entitlements.active.entries) {
        final entitlement = entry.value;
        final productId = entitlement.productIdentifier;
        print('アクティブなエンタイトルメント - プロダクトID: $productId');

        if (productId == _yearlyProductId ||
            productId.toLowerCase().contains('year') ||
            productId.toLowerCase().contains('annual')) {
          hasYearly = true;
          print('年額プランのエンタイトルメントが検出されました: $productId');
        }

        if (productId == _monthlyProductId ||
            productId.toLowerCase().contains('month')) {
          hasMonthly = true;
          print('月額プランのエンタイトルメントが検出されました: $productId');
        }
      }

      setState(() {
        _hasYearlySubscription = hasYearly;
        _hasMonthlySubscription = hasMonthly;

        // 既に契約がある場合、契約していない方をデフォルト選択
        if (hasYearly && !hasMonthly) {
          _isYearlyPlanSelected = false; // 月額を選択状態にする（年額は契約済み）
        } else if (hasMonthly && !hasYearly) {
          _isYearlyPlanSelected = true; // 年額を選択状態にする（月額は契約済み）
        }
      });

      print('年額契約状態: $_hasYearlySubscription');
      print('月額契約状態: $_hasMonthlySubscription');
    } catch (e) {
      print('契約状態チェックエラー: $e');
    }
  }

  // 契約があるかどうかをチェックする関数
  bool get _hasAnySubscription => _hasYearlySubscription || _hasMonthlySubscription;

  // 選択されたプランが契約済みかどうかをチェックする関数
  bool get _isSelectedPlanAlreadySubscribed {
    return (_isYearlyPlanSelected && _hasYearlySubscription) ||
        (!_isYearlyPlanSelected && _hasMonthlySubscription);
  }

  Future<void> _purchasePackage() async {
    // 既に契約済みのプランを選択している場合は何もしない
    if (_isSelectedPlanAlreadySubscribed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('このプランは既にご契約いただいています'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 既に何らかの契約がある場合は警告を表示
    if (_hasAnySubscription) {
      final result = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('プラン変更の確認'),
            content: Text(
                '現在${_hasYearlySubscription ? "年額" : "月額"}プランをご契約中です。\n'
                    '新しいプランに変更しますか？\n\n'
                    '※既存のプランは自動的にキャンセルされません。Apple IDの設定から手動でキャンセルしてください。'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('変更する'),
              ),
            ],
          );
        },
      );

      if (result != true) return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // パッケージの取得
      final offerings = await Purchases.getOfferings();

      // デバッグ出力
      print('利用可能なオファリング: ${offerings.all.keys.join(', ')}');

      // 現在のオファリングがnullの場合でもpremiumオファリングを直接取得
      final offering = offerings.getOffering('premium');
      if (offering == null) {
        throw Exception('現在、購入可能なプランが見つかりません');
      }

      print('選択されたオファリング: ${offering.identifier}');
      print('利用可能なパッケージ:');
      for (var pkg in offering.availablePackages) {
        try {
          print('- パッケージ: ${pkg.identifier}, プロダクト: ${pkg.storeProduct.identifier}');
        } catch (e) {
          print('- パッケージ: ${pkg.identifier} (プロダクト情報にアクセスできません)');
        }
      }

      Package? selectedPackage;

      // 選択されたプランに基づいてパッケージを選択
      if (_isYearlyPlanSelected) {
        // 年額プラン
        // まず、パッケージ識別子で検索
        selectedPackage = offering.availablePackages
            .firstWhere((pkg) => pkg.identifier == _yearlyPackageId,
            orElse: () => null as Package);

        // 見つからない場合は、識別子に「year」を含むパッケージを検索
        if (selectedPackage == null) {
          for (var pkg in offering.availablePackages) {
            if (pkg.identifier.toLowerCase().contains('year') ||
                pkg.identifier.toLowerCase().contains('annual') ||
                pkg.identifier.toLowerCase().contains('yearly')) {
              selectedPackage = pkg;
              break;
            }
          }
        }

        // それでも見つからない場合は、プロダクトIDで検索
        if (selectedPackage == null) {
          for (var pkg in offering.availablePackages) {
            try {
              if (pkg.storeProduct.identifier == _yearlyProductId) {
                selectedPackage = pkg;
                break;
              }
            } catch (_) {
              // storeProductへのアクセスエラーを無視
            }
          }
        }
      } else {
        // 月額プラン
        // まず、パッケージ識別子で検索
        selectedPackage = offering.availablePackages
            .firstWhere((pkg) => pkg.identifier == _monthlyPackageId,
            orElse: () => null as Package);

        // 見つからない場合は、識別子に「month」を含むパッケージを検索
        if (selectedPackage == null) {
          for (var pkg in offering.availablePackages) {
            if (pkg.identifier.toLowerCase().contains('month') ||
                pkg.identifier.toLowerCase().contains('monthly')) {
              selectedPackage = pkg;
              break;
            }
          }
        }

        // それでも見つからない場合は、プロダクトIDで検索
        if (selectedPackage == null) {
          for (var pkg in offering.availablePackages) {
            try {
              if (pkg.storeProduct.identifier == _monthlyProductId) {
                selectedPackage = pkg;
                break;
              }
            } catch (_) {
              // storeProductへのアクセスエラーを無視
            }
          }
        }
      }

      if (selectedPackage == null) {
        throw Exception('選択したプランが見つかりません');
      }

      print('最終的に選択されたパッケージ: ${selectedPackage.identifier}');
      try {
        print('プロダクト: ${selectedPackage.storeProduct.identifier}');
        print('価格: ${selectedPackage.storeProduct.priceString}');
      } catch (e) {
        print('(プロダクト情報へのアクセスエラー: $e)');
      }

      // 購入処理
      final customerInfo = await Purchases.purchasePackage(selectedPackage);

      // 購入成功
      if (customerInfo.entitlements.all.isNotEmpty) {
        // 契約状態を再チェック
        await _checkCurrentSubscription();

        // 購入成功時の処理
        Navigator.pop(context, true);  // 成功して画面を閉じる
      }
    } catch (e) {
      String message = '購入処理中にエラーが発生しました';

      // エラーメッセージの詳細を設定
      if (e is PurchasesError) {
        switch (e.code) {
          case PurchasesErrorCode.purchaseCancelledError:
            message = '購入がキャンセルされました';
            break;
          case PurchasesErrorCode.paymentPendingError:
            message = '支払い処理中です';
            break;
          default:
            message = '購入エラー';
        }
      } else {
        message = e.toString();
      }

      setState(() {
        _errorMessage = message;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // アプリ内ブラウザでURLを開く関数
  Future<void> _launchInAppBrowser(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView, // アプリ内ブラウザで開く
          browserConfiguration: const BrowserConfiguration(
            showTitle: true,
          ),
        );
      } else {
        // URLが開けない場合のエラーハンドリング
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('リンクを開くことができませんでした'),
          ),
        );
      }
    } catch (e) {
      // エラーハンドリング
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: $e'),
        ),
      );
    }
  }

  // プランカードを作成するヘルパー関数
  Widget _buildPlanCard({
    required bool isYearly,
    required bool isSelected,
    required bool isSubscribed,
    required VoidCallback onTap,
  }) {
    final isEnabled = !isSubscribed;

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: isSubscribed
              ? Colors.grey[300]
              : Colors.white,
          border: Border.all(
            color: isSubscribed
                ? Colors.grey
                : (isSelected ? const Color(0xFF4CAF50) : Colors.grey),
            width: isSelected && !isSubscribed ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 契約中の表示またはおすすめバッジ
            Row(
              children: [
                if (isSubscribed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '契約中',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (isYearly)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'おすすめ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isYearly ? '年プラン' : '月プラン',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSubscribed ? Colors.grey[600] : Colors.black,
                  ),
                ),
                Row(
                  children: [
                    if (isYearly && !isSubscribed)
                      Text(
                        '40%お得！',
                        style: TextStyle(
                          color: isSubscribed ? Colors.grey[600] : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSubscribed
                              ? Colors.grey
                              : (isSelected ? const Color(0xFF4CAF50) : Colors.grey),
                          width: 2,
                        ),
                      ),
                      child: (isSelected && !isSubscribed)
                          ? const Center(
                        child: Icon(
                          Icons.check,
                          size: 18,
                          color: Color(0xFF4CAF50),
                        ),
                      )
                          : isSubscribed
                          ? const Center(
                        child: Icon(
                          Icons.check,
                          size: 18,
                          color: Colors.grey,
                        ),
                      )
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            if (isYearly)
              Row(
                children: [
                  Text(
                    '¥3,600',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSubscribed ? Colors.grey[600] : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '¥6,000',
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '(税込)',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Text(
                    '¥500 ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSubscribed ? Colors.grey[600] : Colors.black,
                    ),
                  ),
                  Text(
                    '(税込)',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSubscription) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'キャンセル',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Text(
                  'JAM プレミアム',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              color: const Color(0xFFFDF6E7), // Light cream background
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Banner image
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/jam_subscription.png', // Add your banner image
                            width: 250,
                          ),
                        ],
                      ),
                    ),

                    // Subscription options
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Yearly plan
                          _buildPlanCard(
                            isYearly: true,
                            isSelected: _isYearlyPlanSelected,
                            isSubscribed: _hasYearlySubscription,
                            onTap: () {
                              setState(() {
                                _isYearlyPlanSelected = true;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          // Monthly plan
                          _buildPlanCard(
                            isYearly: false,
                            isSelected: !_isYearlyPlanSelected,
                            isSubscribed: _hasMonthlySubscription,
                            onTap: () {
                              setState(() {
                                _isYearlyPlanSelected = false;
                              });
                            },
                          ),

                          const SizedBox(height: 24),

                          // App Store text
                          Center(
                            child: Text(
                              'App Store からいつでも解約できます',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Subscribe button
                          ElevatedButton(
                            onPressed: (_isLoading || _isSelectedPlanAlreadySubscribed)
                                ? null
                                : _purchasePackage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSelectedPlanAlreadySubscribed
                                  ? Colors.grey
                                  : const Color(0xFF4CAF50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              _isSelectedPlanAlreadySubscribed
                                  ? '契約中'
                                  : (_isYearlyPlanSelected
                                  ? '年プランで登録する'
                                  : '月プランで登録する'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // エラーメッセージ表示
                          // if (_errorMessage != null)
                          //   Padding(
                          //     padding: const EdgeInsets.only(top: 8.0),
                          //     child: Text(
                          //       _errorMessage!,
                          //       style: const TextStyle(
                          //         color: Colors.red,
                          //         fontSize: 14,
                          //       ),
                          //       textAlign: TextAlign.center,
                          //     ),
                          //   ),

                          const SizedBox(height: 24),

                          // Terms and conditions
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '注意事項（必ずお読みください）',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'JAM プレミアムにご登録いただくと、',
                                      ),
                                      WidgetSpan(
                                        child: GestureDetector(
                                          onTap: () => _launchInAppBrowser(_termsOfServiceUrl),
                                          child: const Text(
                                            '利用規約',
                                            style: TextStyle(
                                              color: Colors.green,
                                              decoration: TextDecoration.underline,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: 'と'),
                                      WidgetSpan(
                                        child: GestureDetector(
                                          onTap: () => _launchInAppBrowser(_privacyPolicyUrl),
                                          child: const Text(
                                            'プライバシーポリシー',
                                            style: TextStyle(
                                              color: Colors.green,
                                              decoration: TextDecoration.underline,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: 'に同意したことになります。'),
                                      const TextSpan(text: 'JAMプレミアムは、有効期限終了前の24時間以内にAppleIDに自動課金されます。'),
                                      const TextSpan(text: '解約の場合、それまでにAppleID設定にて自動更新を停止してください。'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}