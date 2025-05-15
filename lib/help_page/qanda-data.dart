import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class FAQDatabaseInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  // FAQデータの初期化
  Future<void> initializeFAQDatabase() async {
    try {
      await initializeQAList();
      print('FAQデータベースの初期化が完了しました');
    } catch (e) {
      print('FAQデータベース初期化エラー: $e');
    }
  }

  // QAリストの初期化（画像のFirestoreデータ構造に合わせる）
  Future<void> initializeQAList() async {
    final CollectionReference qaCollection = _firestore.collection('q-a_list');

    final List<Map<String, dynamic>> qaData = [
      {
        'answer': 'JapanAnimeMapsは、日本全国のアニメ聖地巡礼スポットを集めた位置情報アプリです。アニメの舞台となった場所や、関連イベント情報などを簡単に検索できます。ユーザー同士でスポット情報を共有することもでき、アニメファンのための新しい旅行体験を提供しています。',
        'createdAt': Timestamp.now(),
        'genre': 'サービスについて',
        'lastUpdated': Timestamp.now(),
        'question': 'JapanAnimeMapsとは何ですか？',
        'questionId': _generateQuestionId(),
        'title': 'アプリの基本情報',
      },
      {
        'answer': '当社は主に3つのサービスを提供しています。\n1. JapanAnimeMapsの開発・運営：アニメ聖地巡礼のためのスマートフォンアプリ\n2. 地域活性化事業：アニメツーリズムを活用した地域振興企画\n3. 受託開発事業：アニメ関連のアプリやウェブサイトの開発',
        'createdAt': Timestamp.now(),
        'genre': 'サービスについて',
        'lastUpdated': Timestamp.now(),
        'question': 'どのようなサービスを提供していますか？',
        'questionId': _generateQuestionId(),
        'title': 'サービス内容',
      },
      {
        'answer': 'JapanAnimeMapsの基本機能は無料でご利用いただけます。一部の高度な機能や広告非表示などのプレミアム機能は有料となります。また、地域活性化事業や受託開発は、個別にお見積りさせていただいております。詳細は各サービスのページをご確認ください。',
        'createdAt': Timestamp.now(),
        'genre': 'サービスについて',
        'lastUpdated': Timestamp.now(),
        'question': 'サービスは無料で利用できますか？',
        'questionId': _generateQuestionId(),
        'title': '料金について',
      },
      {
        'answer': 'アプリまたはウェブサイトから「アカウント作成」ボタンをタップし、必要情報を入力することでアカウントを作成できます。メールアドレスの他、Google、Apple、Twitterのアカウントを利用したサインアップも可能です。詳しい手順はガイドをご覧ください。',
        'createdAt': Timestamp.now(),
        'genre': 'アカウントについて',
        'lastUpdated': Timestamp.now(),
        'question': 'アカウントの作成方法を教えてください',
        'questionId': _generateQuestionId(),
        'title': 'アカウント作成方法',
      },
      {
        'answer': 'ログイン画面の「パスワードをお忘れですか？」リンクから、登録済みのメールアドレスにパスワードリセット用のリンクを送信できます。メールに記載されたリンクから新しいパスワードを設定してください。SNSアカウントでログインしている場合は、該当するSNSからの認証をお試しください。',
        'createdAt': Timestamp.now(),
        'genre': 'アカウントについて',
        'lastUpdated': Timestamp.now(),
        'question': 'パスワードを忘れた場合はどうすればいいですか？',
        'questionId': _generateQuestionId(),
        'title': 'パスワードリセット',
      },
      {
        'answer': 'ログイン後、アプリまたはウェブサイトのマイページから「アカウント設定」を選択すると、プロフィール情報やメールアドレスなどの変更が可能です。なお、セキュリティ上の理由から、メールアドレスの変更時は確認メールが送信され、認証が必要となります。',
        'createdAt': Timestamp.now(),
        'genre': 'アカウントについて',
        'lastUpdated': Timestamp.now(),
        'question': 'アカウント情報の変更方法を教えてください',
        'questionId': _generateQuestionId(),
        'title': 'アカウント情報変更',
      },
      {
        'answer': 'iOSをご利用の方はApp Store、Androidをご利用の方はGoogle Playからダウンロードいただけます。',
        'createdAt': Timestamp.now(),
        'genre': 'アプリについて',
        'lastUpdated': Timestamp.now(),
        'question': 'アプリはどこからダウンロードできますか？',
        'questionId': _generateQuestionId(),
        'title': 'アプリダウンロード',
      },
      {
        'answer': 'アプリの基本的な使い方は以下の通りです：\n1. マップ画面でアニメの聖地スポットを探す\n2. アニメ作品から関連スポットを検索\n3. スポットの詳細情報や他ユーザーの投稿を閲覧\n4. 実際に訪れたスポットを投稿・共有\n詳しい使い方はユーザーガイドをご覧ください。',
        'createdAt': Timestamp.now(),
        'genre': 'アプリについて',
        'lastUpdated': Timestamp.now(),
        'question': 'アプリの使い方を教えてください',
        'questionId': _generateQuestionId(),
        'title': 'アプリ基本操作',
      },
      {
        'answer': '位置情報を許可いただくことで、現在地周辺のアニメスポットを表示したり、最適なルート案内を提供したりすることが可能になります。また、実際にスポットを訪れた際の投稿時にも活用されます。位置情報の利用は任意ですが、許可いただくことでより便利にご利用いただけます。プライバシーについてはプライバシーポリシーをご確認ください。',
        'createdAt': Timestamp.now(),
        'genre': 'アプリについて',
        'lastUpdated': Timestamp.now(),
        'question': '位置情報の許可が必要なのはなぜですか？',
        'questionId': _generateQuestionId(),
        'title': '位置情報について',
      },
      {
        'answer': '当社では自治体様との連携として、地域の観光資源とアニメを組み合わせたプロモーション企画、オリジナルスタンプラリーの実施、アプリ内での地域特集ページの作成など、様々な取り組みを行っています。地域の特性に合わせたカスタムプランをご提案いたしますので、お気軽にお問い合わせください。',
        'createdAt': Timestamp.now(),
        'genre': 'ビジネス連携',
        'lastUpdated': Timestamp.now(),
        'question': '自治体としてアニメツーリズムを活用したいのですが、どのような連携が可能ですか？',
        'questionId': _generateQuestionId(),
        'title': '自治体との連携',
      },
      {
        'answer': 'はい、JapanAnimeMapsアプリ内での広告掲載が可能です。バナー広告やスポンサードコンテンツなど、様々な広告形態をご用意しております。アニメファンに直接アプローチできる効果的な広告ソリューションをご提案いたします。広告掲載に関する詳細は広告掲載のご案内をご覧いただくか、お問い合わせフォームからご連絡ください。',
        'createdAt': Timestamp.now(),
        'genre': 'ビジネス連携',
        'lastUpdated': Timestamp.now(),
        'question': 'アプリ内での広告掲載は可能ですか？',
        'questionId': _generateQuestionId(),
        'title': '広告掲載について',
      },
      {
        'answer': 'アニメ制作会社様やIPホルダー様との公式タイアップも積極的に行っております。公式情報として作品の聖地情報を掲載することで、ファンの方々により正確で充実した情報を提供できます。また、放映時期に合わせた特集企画なども可能です。詳細はお問い合わせフォームよりご連絡ください。担当者が個別にご説明させていただきます。',
        'createdAt': Timestamp.now(),
        'genre': 'ビジネス連携',
        'lastUpdated': Timestamp.now(),
        'question': 'アニメ制作会社として、当社作品の聖地情報を掲載したいです',
        'questionId': _generateQuestionId(),
        'title': 'コンテンツ提携',
      },
      {
        'answer': '不適切な投稿を発見された場合は、該当投稿の右上にある「・・・」メニューから「報告する」を選択してください。報告内容を確認の上、当社ガイドラインに違反していると判断した場合は、速やかに対応いたします。コミュニティガイドラインについてはこちらをご確認ください。',
        'createdAt': Timestamp.now(),
        'genre': 'お問い合わせ',
        'lastUpdated': Timestamp.now(),
        'question': '不適切な投稿を見つけた場合どうすればいいですか？',
        'questionId': _generateQuestionId(),
        'title': '不適切投稿の報告',
      },
      {
        'answer': '当社の採用情報は採用情報ページにて公開しております。エンジニア、デザイナー、マーケティング、営業など様々な職種で随時採用を行っております。新卒採用については、毎年10月頃から説明会を開始しますので、ぜひチェックしてみてください。',
        'createdAt': Timestamp.now(),
        'genre': 'お問い合わせ',
        'lastUpdated': Timestamp.now(),
        'question': '採用情報はどこで確認できますか？',
        'questionId': _generateQuestionId(),
        'title': '採用情報',
      },
      {
        'answer': '取材や講演依頼については、pr@animetourism.co.jpまでご連絡ください。メディア掲載実績やこれまでの講演テーマなどについてはメディア掲載・講演実績のページをご参照ください。',
        'createdAt': Timestamp.now(),
        'genre': 'お問い合わせ',
        'lastUpdated': Timestamp.now(),
        'question': '取材や講演依頼はどこに連絡すればいいですか？',
        'questionId': _generateQuestionId(),
        'title': '取材・講演依頼',
      },
    ];

    // バッチ処理でデータを追加
    final batch = _firestore.batch();
    for (var data in qaData) {
      final docRef = qaCollection.doc(); // 自動生成IDを使用
      batch.set(docRef, data);
    }
    return batch.commit();
  }

  // 質問IDの生成（YYYYMMDD-ランダム文字列の形式）
  String _generateQuestionId() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomStr = _uuid.v4().substring(0, 12).toUpperCase(); // UUIDの最初の12文字を使用
    return '$dateStr-$randomStr';
  }
}