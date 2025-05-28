/// テキスト変換に関するユーティリティクラス
class TextUtils {
  /// カタカナからひらがなの変換マップ
  static const Map<String, String> _katakanaToHiraganaMap = {
    'ア': 'あ',
    'イ': 'い',
    'ウ': 'う',
    'エ': 'え',
    'オ': 'お',
    'カ': 'か',
    'キ': 'き',
    'ク': 'く',
    'ケ': 'け',
    'コ': 'こ',
    'サ': 'さ',
    'シ': 'し',
    'ス': 'す',
    'セ': 'せ',
    'ソ': 'そ',
    'タ': 'た',
    'チ': 'ち',
    'ツ': 'つ',
    'テ': 'て',
    'ト': 'と',
    'ナ': 'な',
    'ニ': 'に',
    'ヌ': 'ぬ',
    'ネ': 'ね',
    'ノ': 'の',
    'ハ': 'は',
    'ヒ': 'ひ',
    'フ': 'ふ',
    'ヘ': 'へ',
    'ホ': 'ほ',
    'マ': 'ま',
    'ミ': 'み',
    'ム': 'む',
    'メ': 'め',
    'モ': 'も',
    'ヤ': 'や',
    'ユ': 'ゆ',
    'ヨ': 'よ',
    'ラ': 'ら',
    'リ': 'り',
    'ル': 'る',
    'レ': 'れ',
    'ロ': 'ろ',
    'ワ': 'わ',
    'ヲ': 'を',
    'ン': 'ん',
    'ガ': 'が',
    'ギ': 'ぎ',
    'グ': 'ぐ',
    'ゲ': 'げ',
    'ゴ': 'ご',
    'ザ': 'ざ',
    'ジ': 'じ',
    'ズ': 'ず',
    'ゼ': 'ぜ',
    'ゾ': 'ぞ',
    'ダ': 'だ',
    'ヂ': 'ぢ',
    'ヅ': 'づ',
    'デ': 'で',
    'ド': 'ど',
    'バ': 'ば',
    'ビ': 'び',
    'ブ': 'ぶ',
    'ベ': 'べ',
    'ボ': 'ぼ',
    'パ': 'ぱ',
    'ピ': 'ぴ',
    'プ': 'ぷ',
    'ペ': 'ぺ',
    'ポ': 'ぽ',
    'ャ': 'ゃ',
    'ュ': 'ゅ',
    'ョ': 'ょ',
    'ッ': 'っ',
    'ー': '-',
  };

  /// カタカナをひらがなに変換する
  ///
  /// [kata] カタカナを含む文字列
  /// 戻り値: ひらがなに変換された文字列
  static String katakanaToHiragana(String kata) {
    String result = kata;
    _katakanaToHiraganaMap.forEach((katakana, hiragana) {
      result = result.replaceAll(katakana, hiragana);
    });
    return result;
  }

  /// ソート用のキーを生成する
  /// アルファベットで始まる場合は末尾に配置するため「ん」を先頭に付ける
  ///
  /// [name] アニメ名などの文字列
  /// 戻り値: ソート用のキー文字列
  static String getSortKey(String name) {
    if (name.isEmpty) return '';

    String hiragana = katakanaToHiragana(name);

    // アルファベットで始まる場合は末尾に配置
    if (RegExp(r'^[A-Za-z]').hasMatch(name)) {
      return 'ん' + name.toLowerCase();
    }

    return hiragana;
  }

  /// 名前を比較する（アルファベット文字列を末尾に配置）
  ///
  /// [a] 比較対象の文字列A
  /// [b] 比較対象の文字列B
  /// 戻り値: 比較結果（負の値、0、正の値）
  static int compareNames(String a, String b) {
    if (a.startsWith('ん') && !b.startsWith('ん')) {
      return 1;
    } else if (!a.startsWith('ん') && b.startsWith('ん')) {
      return -1;
    } else if (a.startsWith('ん') && b.startsWith('ん')) {
      return a.substring(1).compareTo(b.substring(1));
    }
    return a.compareTo(b);
  }
}