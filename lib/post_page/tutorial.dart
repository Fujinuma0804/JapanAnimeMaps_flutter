import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialOverlay extends StatefulWidget {
  final Widget child;

  const TutorialOverlay({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  _TutorialOverlayState createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  int _currentStep = 0;
  bool _showTutorial = true;

  final List<TutorialStep> _tutorialSteps = [
    TutorialStep(
      title: 'タブの説明',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'アプリには3つのタブがあります：',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: '• おすすめ：',
                ),
                TextSpan(
                  text: 'みんなの投稿が表示されます',
                ),
              ],
            ),
          ),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: '• コミュニティ：',
                ),
                TextSpan(
                  text: 'グループでの会話ができます',
                ),
              ],
            ),
          ),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: '• 運営：',
                ),
                TextSpan(
                  text: '重要なお知らせを確認できます',
                ),
              ],
            ),
          ),
        ],
      ),
      targetAlignment: Alignment.center,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('first_launch') ?? true;
    if (!isFirstLaunch) {
      setState(() {
        _showTutorial = false;
      });
    }
  }

  Future<void> _finishTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch', false);
    setState(() {
      _showTutorial = false;
    });
  }

  void _nextStep() {
    if (_currentStep < _tutorialSteps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _finishTutorial();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showTutorial) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        // 半透明のオーバーレイ
        Container(
          color: Colors.black.withOpacity(0.5),
          child: Stack(
            children: [
              // 説明カード
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tutorialSteps[_currentStep].title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _tutorialSteps[_currentStep].content,
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_currentStep + 1}/3',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: _nextStep,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                '次へ',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TutorialStep {
  final String title;
  final Widget content;
  final Alignment targetAlignment;

  const TutorialStep({
    required this.title,
    required this.content,
    required this.targetAlignment,
  });
}
