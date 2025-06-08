import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final String _yearlyPackageId = '\$rc_annual'; // 文字列として$を含める
  final String _monthlyPackageId = '\$rc_monthly'; // 文字列として$を含める

  bool _isLoading = false;
  String? _errorMessage;

  // 契約状態を管理する変数
  bool _hasYearlySubscription = false;
  bool _hasMonthlySubscription = false;
  bool _isCheckingSubscription = true;

  // 多言語対応
  String _userLanguage = 'English';
  late User _user;
  late Stream<DocumentSnapshot> _userStream;

  // 利用規約とプライバシーポリシーのURL
  final String _termsOfServiceUrl = 'https://animetourism.co.jp/terms.html';
  final String _privacyPolicyUrl = 'https://animetourism.co.jp/privacy.html';

  // 多言語対応テキスト
  Map<String, Map<String, String>> get _texts =>
      {
        'Japanese': {
          'title': 'JAM プレミアム',
          'cancel': 'キャンセル',
          'premiumFeatures': '✨ プレミアムで快適体験',
          'adFree': '広告非表示',
          'adFreeDesc': '集中して\n検索できます',
          'unlimited': '検索無制限',
          'unlimitedDesc': '思う存分\n探せます',
          'enjoyMore': 'より快適なJAM体験をお楽しみください',
          'selectPlan': 'プランを選択してください',
          'yearPlan': '年プラン',
          'monthPlan': '月プラン',
          'recommended': 'おすすめ',
          'subscribed': '契約中',
          'discount': '40%お得！',
          'appStoreCancel': 'App Store からいつでも解約できます',
          'subscribeYear': '年プランで登録する',
          'subscribeMonth': '月プランで登録する',
          'termsTitle': '注意事項（必ずお読みください）',
          'termsContent': 'JAM プレミアムにご登録いただくと、',
          'terms': '利用規約',
          'privacy': 'プライバシーポリシー',
          'agreeTerms': 'に同意したことになります。',
          'autoRenewal': 'JAMプレミアムは、有効期限終了前の24時間以内にAppleIDに自動課金されます。',
          'cancelInfo': '解約の場合、それまでにAppleID設定にて自動更新を停止してください。',
          'alreadySubscribed': 'このプランは既にご契約いただいています',
          'planChangeConfirm': 'プラン変更の確認',
          'planChangeMessage': '現在{currentPlan}プランをご契約中です。\n新しいプランに変更しますか？\n\n※既存のプランは自動的にキャンセルされません。Apple IDの設定から手動でキャンセルしてください。',
          'change': '変更する',
          'yearly': '年額',
          'monthly': '月額',
          'purchaseError': '購入処理中にエラーが発生しました',
          'purchaseCancelled': '購入がキャンセルされました',
          'paymentPending': '支払い処理中です',
          'noPlansAvailable': '現在、購入可能なプランが見つかりません',
          'planNotFound': '選択したプランが見つかりません',
          'linkError': 'リンクを開くことができませんでした',
          'taxIncluded': '(税込)',
        },
        'English': {
          'title': 'JAM Premium',
          'cancel': 'Cancel',
          'premiumFeatures': '✨ Premium Experience',
          'adFree': 'Ad-Free',
          'adFreeDesc': 'Focus on\nsearching',
          'unlimited': 'Unlimited Search',
          'unlimitedDesc': 'Explore to your\nheart\'s content',
          'enjoyMore': 'Enjoy a more comfortable JAM experience',
          'selectPlan': 'Please select a plan',
          'yearPlan': 'Annual Plan',
          'monthPlan': 'Monthly Plan',
          'recommended': 'Recommended',
          'subscribed': 'Subscribed',
          'discount': '40% Off!',
          'appStoreCancel': 'Cancel anytime from App Store',
          'subscribeYear': 'Subscribe to Annual Plan',
          'subscribeMonth': 'Subscribe to Monthly Plan',
          'termsTitle': 'Important Notice (Please Read)',
          'termsContent': 'By subscribing to JAM Premium, you agree to our ',
          'terms': 'Terms of Service',
          'privacy': 'Privacy Policy',
          'agreeTerms': '.',
          'autoRenewal': 'JAM Premium will be automatically charged to your Apple ID within 24 hours before the expiration date.',
          'cancelInfo': 'To cancel, please stop auto-renewal in your Apple ID settings before then.',
          'alreadySubscribed': 'You are already subscribed to this plan',
          'planChangeConfirm': 'Confirm Plan Change',
          'planChangeMessage': 'You are currently subscribed to the {currentPlan} plan.\nWould you like to change to a new plan?\n\n※Existing plans will not be automatically cancelled. Please manually cancel from your Apple ID settings.',
          'change': 'Change',
          'yearly': 'annual',
          'monthly': 'monthly',
          'purchaseError': 'An error occurred during purchase',
          'purchaseCancelled': 'Purchase was cancelled',
          'paymentPending': 'Payment is pending',
          'noPlansAvailable': 'No purchasable plans are currently available',
          'planNotFound': 'Selected plan not found',
          'linkError': 'Could not open link',
          'taxIncluded': '(Tax Included)',
        },
      };

  String _getText(String key) {
    final result = _texts[_userLanguage]?[key] ?? _texts['English']![key]!;
    print(
        'PaymentSubscriptionScreen - _getText($key) with language $_userLanguage = $result');
    return result;
  }

  @override
  void initState() {
    super.initState();
    _getUser();
    _setupUserStream();
    _setupPurchases();
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
      print('PaymentSubscriptionScreen - Stream listener called');
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final language = data['language'] ?? 'English';
        print('PaymentSubscriptionScreen - Language from Firestore: $language');

        setState(() {
          _userLanguage = language;
        });

        print('PaymentSubscriptionScreen - Updated language: $_userLanguage');
      } else {
        print('PaymentSubscriptionScreen - Document does not exist');
      }
    });
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
            print('- パッケージ: ${pkg
                .identifier} (プロダクト情報へのアクセスエラー: $e)');
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
            print('- パッケージ: ${pkg
                .identifier} (プロダクト情報へのアクセスエラー: $e)');
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
      print('アクティブなサブスクリプション: ${customerInfo
          .activeSubscriptions}');
      print('アクティブなエンタイトルメント: ${customerInfo.entitlements.active
          .keys}');

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
  bool get _hasAnySubscription =>
      _hasYearlySubscription || _hasMonthlySubscription;

  // 選択されたプランが契約済みかどうかをチェックする関数
  bool get _isSelectedPlanAlreadySubscribed {
    return (_isYearlyPlanSelected && _hasYearlySubscription) ||
        (!_isYearlyPlanSelected && _hasMonthlySubscription);
  }

  Future<void> _purchasePackage() async {
    // 既に契約済みのプランを選択している場合は何もしない
    if (_isSelectedPlanAlreadySubscribed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getText('alreadySubscribed')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 既に何らかの契約がある場合は警告を表示
    if (_hasAnySubscription) {
      final currentPlan = _hasYearlySubscription
          ? _getText('yearly')
          : _getText('monthly');
      final message = _getText('planChangeMessage').replaceAll(
          '{currentPlan}', currentPlan);

      final result = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(_getText('planChangeConfirm')),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(_getText('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(_getText('change')),
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
        throw Exception(_getText('noPlansAvailable'));
      }

      print('選択されたオファリング: ${offering.identifier}');
      print('利用可能なパッケージ:');
      for (var pkg in offering.availablePackages) {
        try {
          print('- パッケージ: ${pkg.identifier}, プロダクト: ${pkg.storeProduct
              .identifier}');
        } catch (e) {
          print('- パッケージ: ${pkg
              .identifier} (プロダクト情報にアクセスできません)');
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
        throw Exception(_getText('planNotFound'));
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
        Navigator.pop(context, true); // 成功して画面を閉じる
      }
    } catch (e) {
      String message = _getText('purchaseError');

      // エラーメッセージの詳細を設定
      if (e is PurchasesError) {
        switch (e.code) {
          case PurchasesErrorCode.purchaseCancelledError:
            message = _getText('purchaseCancelled');
            break;
          case PurchasesErrorCode.paymentPendingError:
            message = _getText('paymentPending');
            break;
          default:
            message = _getText('purchaseError');
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
          SnackBar(
            content: Text(_getText('linkError')),
          ),
        );
      }
    } catch (e) {
      // エラーハンドリング
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getText('linkError')}: $e'),
        ),
      );
    }
  }

  // プレミアム機能セクションを作成する関数
  Widget _buildPremiumFeaturesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.1),
            const Color(0xFF81C784).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getText('premiumFeatures'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 機能一覧
          Row(
            children: [
              // 広告非表示
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.block,
                  iconColor: const Color(0xFFFF6B6B),
                  title: _getText('adFree'),
                  subtitle: _getText('adFreeDesc'),
                  gradient: [
                    const Color(0xFFFF6B6B).withOpacity(0.1),
                    const Color(0xFFFF8A80).withOpacity(0.05),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 検索無制限
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.search,
                  iconColor: const Color(0xFF4CAF50),
                  title: _getText('unlimited'),
                  subtitle: _getText('unlimitedDesc'),
                  gradient: [
                    const Color(0xFF4CAF50).withOpacity(0.1),
                    const Color(0xFF81C784).withOpacity(0.05),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 補足テキスト
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star,
                  color: Colors.amber[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _getText('enjoyMore'),
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 機能カードを作成する関数
  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // アイコン
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),

          const SizedBox(height: 8),

          // タイトル
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: iconColor.withOpacity(0.9),
            ),
          ),

          const SizedBox(height: 4),

          // サブタイトル
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              height: 1.2,
            ),
          ),
        ],
      ),
    );
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
          boxShadow: isSelected && !isSubscribed ? [
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
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
                    child: Text(
                      _getText('subscribed'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  if (isYearly)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getText('recommended'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
                  isYearly ? _getText('yearPlan') : _getText('monthPlan'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSubscribed ? Colors.grey[600] : Colors.black,
                  ),
                ),
                Row(
                  children: [
                    if (isYearly && !isSubscribed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getText('discount'),
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
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
                              : (isSelected ? const Color(0xFF4CAF50) : Colors
                              .grey),
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
            const SizedBox(height: 4),
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
                  const Text(
                    '¥6,000',
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    _getText('taxIncluded'),
                    style: const TextStyle(
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
                    _getText('taxIncluded'),
                    style: const TextStyle(
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
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: MediaQuery
                .of(context)
                .size
                .height * 0.85,
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

        if (snapshot.hasData && snapshot.data != null) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData != null) {
            _userLanguage = userData['language'] ?? 'English';
          }
        }

        if (_isCheckingSubscription) {
          return Container(
            height: MediaQuery
                .of(context)
                .size
                .height * 0.85,
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
          height: MediaQuery
              .of(context)
              .size
              .height * 0.85,
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        _getText('cancel'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      _getText('title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 60), // バランス調整
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
                                _userLanguage == 'Japanese'
                                    ? 'assets/images/jam_subscription.png'
                                    : 'assets/images/jam_subscription_en.png',
                                width: 250,
                              ),
                            ],
                          ),
                        ),

                        // プレミアム機能セクション
                        _buildPremiumFeaturesSection(),

                        // Subscription options
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // プランセクションタイトル
                              Text(
                                _getText('selectPlan'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 16),

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
                                  _getText('appStoreCancel'),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Subscribe button
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  gradient: (_isLoading ||
                                      _isSelectedPlanAlreadySubscribed)
                                      ? null
                                      : const LinearGradient(
                                    colors: [
                                      Color(0xFF4CAF50),
                                      Color(0xFF66BB6A)
                                    ],
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: (_isLoading ||
                                      _isSelectedPlanAlreadySubscribed)
                                      ? null
                                      : _purchasePackage,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isSelectedPlanAlreadySubscribed
                                        ? Colors.grey
                                        : Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
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
                                        ? _getText('subscribed')
                                        : (_isYearlyPlanSelected
                                        ? _getText('subscribeYear')
                                        : _getText('subscribeMonth')),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

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
                                    Text(
                                      _getText('termsTitle'),
                                      style: const TextStyle(
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
                                          TextSpan(
                                            text: _getText('termsContent'),
                                          ),
                                          WidgetSpan(
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _launchInAppBrowser(
                                                      _termsOfServiceUrl),
                                              child: Text(
                                                _getText('terms'),
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  decoration: TextDecoration
                                                      .underline,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TextSpan(
                                              text: _userLanguage == 'Japanese'
                                                  ? 'と'
                                                  : ' and '),
                                          WidgetSpan(
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _launchInAppBrowser(
                                                      _privacyPolicyUrl),
                                              child: Text(
                                                _getText('privacy'),
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  decoration: TextDecoration
                                                      .underline,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TextSpan(
                                              text: _getText('agreeTerms')),
                                          TextSpan(
                                              text: _getText('autoRenewal')),
                                          TextSpan(
                                              text: _getText('cancelInfo')),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),
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
      },
    );
  }
}