import 'package:flutter/material.dart';
import 'dart:math' as math;

class BookOpeningEffect extends StatefulWidget {
  const BookOpeningEffect({Key? key}) : super(key: key);

  @override
  State<BookOpeningEffect> createState() => _BookOpeningEffectState();
}

class _BookOpeningEffectState extends State<BookOpeningEffect>
    with TickerProviderStateMixin {
  late AnimationController _openController;
  late AnimationController _pageController;
  late AnimationController _shadowController;
  late AnimationController _zoomController;

  late Animation<double> _openAnimation;
  late Animation<double> _pageFlipAnimation;
  late Animation<double> _shadowAnimation;
  late Animation<double> _zoomAnimation;
  late Animation<Offset> _positionAnimation;

  bool _isOpen = false;
  bool _isZoomed = false;
  int _currentPagePair = 0;
  double _dragProgress = 0.0;
  bool _isDragging = false;
  bool _isFlipping = false;

  // 見開きページデータ
  final List<Map<String, dynamic>> _pageSpread = [
    {
      'left': {
        'title': '物語の本',
        'content': 'この物語は、勇気と友情、そして成長について語る冒険の物語です。\n\n主人公のアリスが不思議な世界で出会う様々な体験を通して、人生の大切なことを学んでいく物語をお楽しみください。\n\n美しい挿絵と共に、心温まるストーリーをお届けします。',
        'pageNumber': '',
        'isCover': true,
      },
      'right': {
        'title': '目次',
        'content': '第一章　はじまり........... 2\n\n第二章　冒険............... 4\n\n第三章　出会い............. 6\n\n第四章　試練............... 8\n\n第五章　成長............... 10\n\n最終章　結末............... 12\n\n\nあとがき................... 14',
        'pageNumber': '1',
        'isCover': false,
      },
    },
    {
      'left': {
        'title': '第一章　はじまり',
        'content': '昔々、ある所に美しい森がありました。その森の奥深くに、小さな村が隠れるように存在していました。\n\n村人たちは平和に暮らしていましたが、この日、不思議な出来事が起こることになります。\n\n朝日が森の木々の間から差し込むと、きらきらと光る粒子が舞い踊り、まるで魔法にかかったような光景が広がりました。\n\nその美しい光景に魅了された少女アリスは、光の粒子を追いかけて森の奥へと向かいました。',
        'pageNumber': '2',
        'isCover': false,
      },
      'right': {
        'title': '',
        'content': '足音だけが響く静寂な森の中で、アリスは心臓の鼓動が早くなるのを感じていました。\n\n「きっと素敵な何かが待っているはず」\n\nそう呟きながら、彼女は勇気を振り絞って歩き続けました。\n\nやがて、森の最も奥深い場所で、アリスは古い石でできた不思議な扉を発見しました。扉には美しい模様が刻まれており、触れると温かな光を放ちました。\n\n「この扉の向こうには何があるのだろう？」',
        'pageNumber': '3',
        'isCover': false,
      },
    },
    {
      'left': {
        'title': '第二章　冒険',
        'content': '扉を開けると、そこには想像もしなかった世界が広がっていました。色とりどりの花が咲き乱れ、空には虹色の鳥たちが舞っています。\n\n「ここは一体どこなの？」\n\nアリスは目を見張りました。この世界のすべてが、まるで絵本の中から飛び出してきたような美しさでした。\n\n空気さえも甘い香りを含んでおり、足元には柔らかな苔が敷き詰められていました。',
        'pageNumber': '4',
        'isCover': false,
      },
      'right': {
        'title': '',
        'content': 'アリスが辺りを見回していると、どこからか優しい声が聞こえてきました。\n\n「ようこそ、アリス」\n\n振り返ると、そこには白いローブを着た優しそうな老人が立っていました。長い髭を蓄え、瞳は星のように輝いています。\n\n「私はこの世界の案内人です。あなたを長い間待っていました。」\n\n老人の言葉に、アリスは不思議な安心感を覚えました。',
        'pageNumber': '5',
        'isCover': false,
      },
    },
    {
      'left': {
        'title': '第三章　出会い',
        'content': '案内人は言いました。「この世界で真の勇気を学ぶために、いくつかの試練があります。しかし心配はいりません。あなたには必ず乗り越えられる力があります。」\n\nアリスは少し緊張しましたが、同時に期待も感じていました。\n\n「どんな試練なのですか？」\n\n「まずは思いやりの心を学ぶことから始めましょう。」\n\n案内人はそう言って、森の奥へと歩き始めました。',
        'pageNumber': '6',
        'isCover': false,
      },
      'right': {
        'title': '',
        'content': '森を歩いていると、小さな鳴き声が聞こえてきました。見ると、翼を怪我した小鳥が木の根元で震えています。\n\n「かわいそうに...」\n\nアリスは迷わず小鳥を手に取り、優しく介抱しました。すると不思議なことに、小鳥の傷はたちまち治ってしまいました。\n\n「思いやりの心が、最初の魔法を呼んだのです」案内人が微笑みました。\n\n小鳥は嬉しそうに鳴いて、空高く舞い上がりました。',
        'pageNumber': '7',
        'isCover': false,
      },
    },
    {
      'left': {
        'title': '第四章　試練',
        'content': '次の試練の場所は、雲に届くほど高い山でした。\n\n「諦めない心を学ぶために、この山を登りましょう」\n\nアリスは山を見上げました。とても高くて、頂上は雲に隠れて見えません。\n\n「本当に登れるのかしら...」\n\n不安になりましたが、案内人の励ましの言葉を思い出し、一歩ずつ登り始めました。\n\n途中で何度も疲れて座り込みましたが、その度に立ち上がり、歩き続けました。',
        'pageNumber': '8',
        'isCover': false,
      },
      'right': {
        'title': '',
        'content': 'ついに山頂に辿り着いたとき、アリスは達成感に満たされていました。\n\n「やったわ！登り切れた！」\n\n山頂からの眺めは息を呑むほど美しく、遠くまで続く緑の大地が一望できました。\n\n「諦めない心が、二つ目の魔法を呼びました」\n\n案内人の言葉と共に、アリスの心に新たな力が宿るのを感じました。困難に立ち向かう勇気が、確実に身についていたのです。',
        'pageNumber': '9',
        'isCover': false,
      },
    },
    {
      'left': {
        'title': '第五章　成長',
        'content': '最後の試練は「謙虚な心」を学ぶことでした。\n\n美しい湖のほとりで、アリスは水面に映る自分の姿を見つめました。\n\n「私は今まで、自分だけで頑張ってきたと思っていました。でも違うのですね。」\n\nアリスは案内人や、出会った生き物たち、そして支えてくれた全ての存在に感謝の気持ちを込めて頭を下げました。\n\nその瞬間、湖面が光り、美しい虹が空に架かりました。',
        'pageNumber': '10',
        'isCover': false,
      },
      'right': {
        'title': '',
        'content': '「素晴らしい。あなたは全ての試練を乗り越えました」\n\n案内人が嬉しそうに言いました。\n\n「成長とは、新しい自分と出会うことなのですね」\n\nアリスの瞳は、新たな希望で輝いていました。試練を通して学んだ思いやり、諦めない心、そして謙虚さが、彼女を以前とは違う人に変えていました。\n\n「これで準備は整いました。本当の冒険の始まりです」',
        'pageNumber': '11',
        'isCover': false,
      },
    },
    {
      'left': {
        'title': '最終章　結末',
        'content': '「あなたは立派に成長しました」案内人が微笑みました。\n\n「これでこの世界での学びは終わりです。でも、本当の冒険はこれからです。」\n\n気がつくと、アリスは元の森にいました。しかし、彼女の心には新しい力が宿っていました。\n\n思いやりの心、諦めない勇気、そして謙虚さ。これらの宝物を胸に、アリスは新たな一歩を踏み出しました。',
        'pageNumber': '12',
        'isCover': false,
      },
      'right': {
        'title': '',
        'content': '森を出ると、村の人たちが温かく迎えてくれました。\n\n「アリス、おかえり！」\n\nみんなの笑顔を見て、アリスは心から幸せを感じました。\n\nそして、これから始まる新しい冒険に、胸を躍らせるのでした。\n\n〜 おわり 〜\n\n\nこの物語があなたの心に\n小さな勇気の種を\n植えることができますように。',
        'pageNumber': '13',
        'isCover': false,
      },
    },
  ];

  @override
  void initState() {
    super.initState();

    _openController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pageController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _shadowController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    _openAnimation = Tween<double>(
      begin: 0.0,
      end: math.pi * 0.5, // 完全に平らに（90度）
    ).animate(CurvedAnimation(
      parent: _openController,
      curve: Curves.easeInOutBack,
    ));

    _pageFlipAnimation = Tween<double>(
      begin: 0.0,
      end: math.pi,
    ).animate(CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeInOutCubic,
    ));

    _shadowAnimation = Tween<double>(
      begin: 0.04,
      end: 0.22,
    ).animate(CurvedAnimation(
      parent: _shadowController,
      curve: Curves.easeInOut,
    ));

    _zoomAnimation = Tween<double>(
      begin: 1.0,
      end: 1.35,
    ).animate(CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOutCubic,
    ));

    _positionAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.1),
    ).animate(CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOutCubic,
    ));

    _shadowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _openController.dispose();
    _pageController.dispose();
    _shadowController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    _isDragging = true;
    _openController.stop();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    if (!_isOpen) {
      // 本を開く動作
      final screenWidth = MediaQuery.of(context).size.width;
      final delta = details.delta.dx / screenWidth;
      setState(() {
        _dragProgress = (_dragProgress + delta * 2.0).clamp(0.0, 1.0);
        _openController.value = _dragProgress;
      });
    } else if (_isZoomed && !_isFlipping) {
      // ページめくり
      final threshold = 45.0;
      if (details.delta.dx.abs() > threshold) {
        if (details.delta.dx > 0) {
          _previousPageSpread();
        } else {
          _nextPageSpread();
        }
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    if (!_isOpen) {
      final velocity = details.velocity.pixelsPerSecond.dx;

      if (velocity.abs() > 600) {
        if (velocity > 0) {
          _animateToOpen();
        } else {
          _animateToClose();
        }
      } else {
        if (_dragProgress > 0.5) {
          _animateToOpen();
        } else {
          _animateToClose();
        }
      }
    }
  }

  void _animateToOpen() {
    _openController.forward().then((_) {
      setState(() {
        _isOpen = true;
        _dragProgress = 1.0;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        _zoomController.forward();
        setState(() {
          _isZoomed = true;
        });
      });
    });
  }

  void _animateToClose() {
    if (_isZoomed) {
      _zoomController.reverse().then((_) {
        setState(() {
          _isZoomed = false;
        });
        Future.delayed(const Duration(milliseconds: 400), () {
          _openController.reverse();
          setState(() {
            _isOpen = false;
            _dragProgress = 0.0;
          });
        });
      });
    } else {
      _openController.reverse();
      setState(() {
        _isOpen = false;
        _dragProgress = 0.0;
      });
    }
  }

  void _nextPageSpread() {
    if (_isFlipping || _currentPagePair >= _pageSpread.length - 1) return;

    setState(() {
      _isFlipping = true;
    });

    _pageController.forward().then((_) {
      setState(() {
        _currentPagePair++;
        _isFlipping = false;
      });
      _pageController.reset();
    });
  }

  void _previousPageSpread() {
    if (_isFlipping || _currentPagePair <= 0) return;

    setState(() {
      _isFlipping = true;
    });

    _pageController.forward().then((_) {
      setState(() {
        _currentPagePair--;
        _isFlipping = false;
      });
      _pageController.reset();
    });
  }

  void _handleTap() {
    if (!_isOpen) {
      _animateToOpen();
    } else if (_isZoomed) {
      _animateToClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bookWidth = screenSize.width * 0.78;
    final bookHeight = bookWidth * 0.7; // A4見開きの比率

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 2.2,
            colors: [
              Color(0xFF151515),
              Color(0xFF050505),
            ],
          ),
        ),
        child: GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          onTap: _handleTap,
          child: SafeArea(
            child: Stack(
              children: [
                // 指示テキスト（上部）
                if (!_isZoomed)
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            _isOpen ? '本を閉じる' : '本を開く',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isDragging ? 'ドラッグ中...' : '左右にスワイプまたはタップ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ページめくり指示（ズーム時）
                if (_isZoomed)
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            '見開き ${_currentPagePair + 1} / ${_pageSpread.length}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '左右スワイプでページめくり・タップで閉じる',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 12,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 本のエフェクト
                Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _openController,
                      _pageController,
                      _shadowController,
                      _zoomController
                    ]),
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _positionAnimation.value.dx * screenSize.width,
                          _positionAnimation.value.dy * screenSize.height,
                        ),
                        child: Transform.scale(
                          scale: _zoomAnimation.value,
                          child: Container(
                            width: bookWidth,
                            height: bookHeight,
                            child: Stack(
                              children: [
                                // 机の表面の影（平らに開いた時の調整）
                                Positioned(
                                  top: bookHeight * 0.035 + (_openAnimation.value * bookHeight * 0.015),
                                  left: bookWidth * 0.02 + (_openAnimation.value * bookWidth * 0.008),
                                  child: Transform.scale(
                                    scaleX: 1.0 + (_openAnimation.value * 0.15),
                                    child: Container(
                                      width: bookWidth * 0.96,
                                      height: bookHeight * 0.93,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(_openAnimation.value >= math.pi * 0.45
                                            ? 0.08 + _shadowAnimation.value * 0.04
                                            : 0.12 + _shadowAnimation.value * 0.08),
                                        borderRadius: BorderRadius.circular(bookWidth * 0.012),
                                      ),
                                    ),
                                  ),
                                ),

                                // 本の厚み（複数レイヤー）
                                for (int i = 0; i < 25; i++)
                                  Positioned(
                                    left: bookWidth * 0.5 - bookWidth * 0.01 - i * (bookWidth * 0.0004),
                                    top: bookHeight * 0.02 + i * (bookHeight * 0.0004),
                                    child: Container(
                                      width: bookWidth * 0.02 + i * (bookWidth * 0.0003),
                                      height: bookHeight * 0.93 - i * (bookHeight * 0.0008),
                                      decoration: BoxDecoration(
                                        color: Color.lerp(
                                          const Color(0xFF8B4513),
                                          const Color(0xFF654321),
                                          i / 25,
                                        ),
                                        borderRadius: BorderRadius.circular(bookWidth * 0.0015),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.25),
                                            offset: Offset(-bookWidth * 0.001, bookWidth * 0.001),
                                            blurRadius: bookWidth * 0.0015,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // 右ページ（固定）
                                Positioned(
                                  left: bookWidth * 0.5,
                                  top: bookHeight * 0.02,
                                  child: Container(
                                    width: bookWidth * 0.48,
                                    height: bookHeight * 0.93,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF8F3),
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(bookWidth * 0.012),
                                        bottomRight: Radius.circular(bookWidth * 0.012),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          offset: Offset(bookWidth * 0.004, bookWidth * 0.004),
                                          blurRadius: bookWidth * 0.01,
                                        ),
                                      ],
                                    ),
                                    child: _buildPageContent(
                                        _pageSpread[_currentPagePair]['right'],
                                        bookWidth,
                                        bookHeight,
                                        true
                                    ),
                                  ),
                                ),

                                // 左ページ（完全に平らに開く）
                                Positioned(
                                  left: bookWidth * 0.02,
                                  top: bookHeight * 0.02,
                                  child: Transform(
                                    alignment: Alignment.centerRight,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.001)
                                      ..rotateY(-_openAnimation.value),
                                    child: Container(
                                      width: bookWidth * 0.48,
                                      height: bookHeight * 0.93,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(bookWidth * 0.012),
                                          bottomLeft: Radius.circular(bookWidth * 0.012),
                                        ),
                                        boxShadow: [
                                          // 開いた時は影を軽減
                                          BoxShadow(
                                            color: Colors.black.withOpacity(_openAnimation.value >= math.pi * 0.45
                                                ? 0.1 : 0.25 + _openAnimation.value * 0.12),
                                            offset: _openAnimation.value >= math.pi * 0.45
                                                ? Offset(-bookWidth * 0.002, bookWidth * 0.002)
                                                : Offset(-bookWidth * 0.005 - _openAnimation.value * bookWidth * 0.002,
                                                bookWidth * 0.005),
                                            blurRadius: _openAnimation.value >= math.pi * 0.45
                                                ? bookWidth * 0.004
                                                : bookWidth * 0.012 + _openAnimation.value * bookWidth * 0.006,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(bookWidth * 0.012),
                                          bottomLeft: Radius.circular(bookWidth * 0.012),
                                        ),
                                        child: Stack(
                                          children: [
                                            // 表紙（外側）
                                            if (_openAnimation.value < math.pi * 0.25)
                                              _buildBookCover(bookWidth, bookHeight),

                                            // 内側のページ
                                            if (_openAnimation.value >= math.pi * 0.25)
                                              _buildPageContent(
                                                  _pageSpread[_currentPagePair]['left'],
                                                  bookWidth,
                                                  bookHeight,
                                                  false
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // ページめくりエフェクト（より自然に）
                                if (_isFlipping && _pageFlipAnimation.value > 0.05)
                                  Positioned(
                                    left: bookWidth * 0.02,
                                    top: bookHeight * 0.02,
                                    child: Transform(
                                      alignment: Alignment.centerRight,
                                      transform: Matrix4.identity()
                                        ..setEntry(3, 2, 0.002)
                                        ..rotateY(-math.pi * 0.5 + _pageFlipAnimation.value),
                                      child: Container(
                                        width: bookWidth * 0.48,
                                        height: bookHeight * 0.93,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(bookWidth * 0.012),
                                            bottomLeft: Radius.circular(bookWidth * 0.012),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3 + _pageFlipAnimation.value * 0.1),
                                              offset: Offset(-bookWidth * 0.008, bookWidth * 0.008),
                                              blurRadius: bookWidth * 0.018,
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(bookWidth * 0.012),
                                            bottomLeft: Radius.circular(bookWidth * 0.012),
                                          ),
                                          child: _buildPageContent(
                                              _pageSpread[(_currentPagePair + 1) % _pageSpread.length]['left'],
                                              bookWidth,
                                              bookHeight,
                                              false
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // 中央の影（本の谷間・完全に開いた時は最小限に）
                                if (_openAnimation.value > 0.08)
                                  Positioned(
                                    left: bookWidth * 0.49,
                                    top: bookHeight * 0.02,
                                    child: Container(
                                      width: bookWidth * 0.02,
                                      height: bookHeight * 0.93,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Colors.black.withOpacity(_openAnimation.value >= math.pi * 0.45
                                                ? 0.02 : 0.06 + _openAnimation.value * 0.1),
                                            Colors.transparent,
                                            Colors.black.withOpacity(_openAnimation.value >= math.pi * 0.45
                                                ? 0.02 : 0.06 + _openAnimation.value * 0.1),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // プログレスインジケーター（下部）
                if (!_isZoomed)
                  Positioned(
                    bottom: 30,
                    left: 30,
                    right: 30,
                    child: AnimatedBuilder(
                      animation: _openController,
                      builder: (context, child) {
                        return Column(
                          children: [
                            Text(
                              '${(_openController.value * 100).round()}%',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _openController.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF2E4A62),
                                        Color(0xFF4A90E2),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                // ページナビゲーション（ズーム時）
                if (_isZoomed)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: _previousPageSpread,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _currentPagePair > 0
                                  ? Colors.white.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.chevron_left,
                              color: _currentPagePair > 0
                                  ? Colors.white.withOpacity(0.85)
                                  : Colors.white.withOpacity(0.3),
                              size: 24,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            '見開き ${_currentPagePair + 1} / ${_pageSpread.length}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _nextPageSpread,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _currentPagePair < _pageSpread.length - 1
                                  ? Colors.white.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.chevron_right,
                              color: _currentPagePair < _pageSpread.length - 1
                                  ? Colors.white.withOpacity(0.85)
                                  : Colors.white.withOpacity(0.3),
                              size: 24,
                            ),
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
    );
  }

  Widget _buildBookCover(double bookWidth, double bookHeight) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E4A62),
            Color(0xFF1E3A52),
            Color(0xFF0E2A42),
          ],
        ),
      ),
      child: Stack(
        children: [
          // レザーの質感とエンボス効果
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.15, -0.15),
                radius: 2.0,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // 表紙デザイン
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(bookWidth * 0.02),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(bookWidth * 0.015),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.auto_stories,
                    color: Colors.white,
                    size: bookWidth * 0.05,
                  ),
                ),
                SizedBox(height: bookHeight * 0.02),
                Text(
                  '物語の本',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: bookWidth * 0.028,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(0.8, 0.8),
                        blurRadius: 1.2,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: bookHeight * 0.01),
                Text(
                  '著者名',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: bookWidth * 0.018,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(Map<String, dynamic> pageData, double bookWidth, double bookHeight, bool isRightPage) {
    final isCover = pageData['isCover'] ?? false;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isRightPage ? Alignment.centerLeft : Alignment.centerRight,
          end: isRightPage ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [
            Color(0xFFF8F6F1),
            Color(0xFFFAF8F3),
            Color(0xFFFCFAF7),
          ],
        ),
      ),
      child: Stack(
        children: [
          // 紙の質感
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 2.5,
                colors: [
                  Colors.white.withOpacity(0.02),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // ページコンテンツ
          Padding(
            padding: EdgeInsets.all(bookWidth * 0.03),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // タイトル
                if (pageData['title'].isNotEmpty)
                  Text(
                    pageData['title'],
                    style: TextStyle(
                      fontSize: _isZoomed ? bookWidth * 0.024 : bookWidth * 0.02,
                      fontWeight: isCover ? FontWeight.w600 : FontWeight.bold,
                      color: const Color(0xFF2E2E2E),
                      letterSpacing: 0.6,
                      height: 1.2,
                    ),
                  ),

                if (pageData['title'].isNotEmpty)
                  SizedBox(height: bookHeight * 0.015),

                // 内容
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      pageData['content'],
                      style: TextStyle(
                        fontSize: _isZoomed ? bookWidth * 0.017 : bookWidth * 0.014,
                        color: const Color(0xFF404040),
                        height: 1.6,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                ),

                // ページ番号
                if (pageData['pageNumber'].isNotEmpty)
                  Align(
                    alignment: isRightPage ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      pageData['pageNumber'],
                      style: TextStyle(
                        fontSize: bookWidth * 0.014,
                        color: const Color(0xFF808080),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}