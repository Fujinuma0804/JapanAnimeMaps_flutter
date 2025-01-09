<div id="top"></div>

## 使用技術一覧

<!-- シールド一覧 -->
<!-- 該当するプロジェクトの中から任意のものを選ぶ-->
<img src="https://skillicons.dev/icons?i=dart,cpp,cmake,html,swift,ruby,css,javascript" /> <br /><br />


## 目次

1. JapanAnimeMapsについて
2. 環境
3. 命名規則について
4. トラブル・問い合わせについて

<!-- READMEの作成方法のドキュメントのリンク -->
<br />
<div align="right">
    <a href="https://apps.apple.com/jp/app/id6608967051"><strong>iOS版公開中 »</strong></a>
</div>
<br />
<!-- Dockerfileのドキュメントのリンク -->
<div align="right">
    <a href="Android版公開準備中へのリンク"><strong>Android版公開準備中 »</strong></a>
</div>
<br />
<!-- プロジェクト名を記載 -->

## JapanAnimeMaps（JAM）

JAMでは、全国のアニメ聖地を巡り、チェックインや思い出を残す、他のユーザの投稿を見て聖地巡礼を楽しむことができます。
実際の画像や動画とアニメの比較も可能で、より充実したアニメ体験が楽しめます。
JAMでアニメの世界を満喫し、素晴らしい聖地巡礼をお楽しみください！
<br></br>
<!-- プロジェクトについて -->

## JapanAnimeMapsについて

<ul>
  <li>クロスプラットフォームFlutterを元に作成</li>
  <li>現状、iOSのみリリース済み。</li>
</ul>

<!-- プロジェクトの概要を記載 -->

  <p align="left">
    <br />
    <!-- プロジェクト詳細にBacklogのWikiのリンク -->
    <a href="https://jam-info.com"><strong>プロジェクト詳細 »</strong></a>
    <br />
    <br />

<p align="right">(<a href="#top">トップへ</a>)</p>

## 環境

<!-- 言語、フレームワーク、ミドルウェア、インフラの一覧とバージョンを記載 -->

| 言語・フレームワーク  | バージョン |
| --------------------- | ---------- |
| Flutter               | 3.22.2     |
| Dart                  | 3.4.3      |


アプリで使用しているパッケージのバージョンについては、pubspec.yaml を参照してください

<p align="right">(<a href="#top">トップへ</a>)</p>

## ディレクトリ構成

<!-- Treeコマンドを使ってディレクトリ構成を記載 -->
# Flutter プロジェクト構成

## ディレクトリ構造

このFlutterプロジェクトは、機能単位でディレクトリを分割する構造を採用しています。以下が詳細な構造です：

```
lib/
├── PostScreen.dart               # 投稿画面のメイン実装
├── firebase_options.dart         # Firebase設定
├── main.dart                     # アプリケーションのエントリーポイント
├── test.dart                     # テストユーティリティ
│
├── apps_about/                   # アプリケーション情報
│   ├── apps_about.dart          # アプリ概要
│   └── license.dart             # ライセンス情報
│
├── badge_ranking/                # バッジ・ランキング機能
│   └── badge_ranking_top.dart    # ランキングトップページ
│
├── components/                   # 再利用可能なコンポーネント
│   ├── ad_helper.dart           # 広告ヘルパー
│   └── ad_mob.dart             # AdMob実装
│
├── help_page/                    # ヘルプ・サポート機能
│   ├── chat_detail.dart         # チャット詳細
│   ├── chat_history.dart        # チャット履歴
│   ├── chat_sender.dart         # メッセージ送信
│   ├── help.dart                # ヘルプメイン
│   └── mail_sender.dart         # メール送信
│
├── login_page/                   # 認証・ログイン機能
│   ├── login_page.dart          # ログインページ
│   ├── mail_login.dart          # メールログイン
│   ├── mail_sign_up1.dart       # メールサインアップ（ステップ1）
│   ├── mail_sign_up2.dart       # メールサインアップ（ステップ2）
│   ├── sign_up.dart             # サインアップメイン
│   └── welcome_page/            # ウェルカムページ
│       ├── welcome_1.dart       # ウェルカム（ステップ1）
│       ├── welcome_2.dart       # ウェルカム（ステップ2）
│       └── welcome_3.dart       # ウェルカム（ステップ3）
│
├── manual_page/                  # マニュアル・規約
│   ├── manual.dart              # マニュアル（日本語）
│   ├── manual_en.dart           # マニュアル（英語）
│   ├── privacypolicy_screen.dart # プライバシーポリシー
│   ├── terms_screen.dart        # 利用規約
│   └── data/                    # 規約データ
│       ├── privacy.dart         # プライバシーポリシーデータ
│       └── terms.dart           # 利用規約データ
│
├── point_page/                   # ポイントシステム
│   ├── chenged_point.dart       # ポイント変更履歴
│   ├── point.dart               # ポイントメイン（日本語）
│   ├── point_en.dart            # ポイントメイン（英語）
│   └── [その他ポイント関連ファイル]
│
├── shop/                         # ショップ機能
│   ├── purchase_agency.dart      # 購入代行
│   ├── shop_cart.dart           # ショッピングカート
│   └── [その他ショップ関連ファイル]
│
└── src/                          # コアユーティリティ
    ├── analytics_repository.dart  # 分析リポジトリ
    ├── bottomnavigationbar.dart   # 下部ナビゲーションバー
    └── [その他ユーティリティファイル]
```

## 主要機能

- **多言語対応**: 日本語・英語のサポート（`_en`ファイルで対応）
- **Firebase連携**: Firebase設定と統合
- **認証システム**: 完全な登録・ログインフロー
- **Eコマース**: ショッピング機能とカート
- **コミュニティ機能**: 投稿とコミュニティ管理
- **ポイントシステム**: ユーザーポイント管理
- **地図連携**: 位置情報ベースの機能
- **アナリティクス**: 組み込み分析機能

## ディレクトリ構成の特徴

このプロジェクトは以下の原則に従って構成されています：

1. **機能単位のアーキテクチャ**
   - 各主要機能は独立したディレクトリを持つ
   - 関連する機能は同じディレクトリにまとめる

2. **多言語対応の準備**
   - 言語ごとに別ファイルを用意
   - `_en`サフィックスで英語版を区別

3. **コンポーネントの再利用性**
   - 共通コンポーネントは`components/`に配置
   - 広告などの外部連携も含む

4. **明確な責任分離**
   - コアユーティリティは`src/`に配置
   - 機能ごとにモデルとビューを分離

## 開発ガイドライン

新機能を追加する際は、以下の点に注意してください：

1. **ファイルの配置**
   - 適切な機能ディレクトリに配置する
   - 必要に応じて新しいディレクトリを作成

2. **命名規則**
   - 既存の命名パターンに従う
   - 機能を明確に示す名前を使用

3. **多言語対応**
   - 必要に応じて各言語版を作成
   - `_en`サフィックスを使用して英語版を作成

4. **コンポーネント化**
   - 再利用可能な要素は`components/`に配置
   - 適切な粒度でコンポーネントを分割

5**ブランチ・レビューについて**
   - ブランチの切り方については、main → develop → そこからブランチを切る
   - devから切ってdevにプルリクを出す
   - レビューについては、基本的には、全員にレビューを投げる。
   - レビューを投げたら、Slackのチャンネルteam-mobile_devへ@channelをメンションして通知する。

<p align="right">(<a href="#top">トップへ</a>)</p>

## トラブル・問い合わせ
<<<<<<< HEAD
もし、何か疑問点などありましたら、<a href="mailto:sota@jam-info.com">メール</a>へご連絡またはSlackなどでご連絡ください。
=======
もし、何か疑問点などありましたら、<a href="mailto:sota@jam-info.com">メール</a>へご連絡またはSlackなどでご連絡ください。
>>>>>>> 00f3b41f64a0a120ba5434a581e4bd3401884201
