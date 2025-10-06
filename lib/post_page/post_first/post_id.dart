import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/post_page/post_first/icon_setup.dart';
import 'package:parts/src/bottomnavigationbar.dart';

class IdSetupScreen extends StatefulWidget {
  const IdSetupScreen({super.key});

  @override
  State<IdSetupScreen> createState() => _IdSetupScreenState();
}

class _IdSetupScreenState extends State<IdSetupScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isChecked = false;
  double _slideValue = 0.0;
  bool _isSliding = false;
  bool _isMailPermissionChecked = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentId();
  }

  Future<void> _loadCurrentId() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userData.exists && userData.data()?['id'] != null) {
          setState(() {
            _controller.text = userData.data()?['id'];
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '設定されているIDの取得に失敗しました';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkIdAvailability(String id) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('id', isEqualTo: id)
        .get();

    // 自分のIDの場合は使用可能
    if (querySnapshot.docs.length == 1) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          querySnapshot.docs.first.id == currentUser.uid) {
        return true;
      }
    }

    return querySnapshot.docs.isEmpty;
  }

  Future<void> _saveId() async {
    if (!_formKey.currentState!.validate()) return;

    final newId = _controller.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ID重複チェック
      final isAvailable = await _checkIdAvailability(newId);
      if (!isAvailable) {
        setState(() {
          _errorMessage = 'このIDは既に使用されています';
          _isLoading = false;
        });
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'id': newId,
          'allowMainNotification': _isMailPermissionChecked,
          'hasSeenWelcome': true,
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainScreen()),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'IDの保存に失敗しました';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSlideComplete() {
    if (_slideValue > 0.9 && _isChecked) {
      _saveId();
    } else {
      setState(() {
        _slideValue = 0.0;
        _isSliding = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'ID設定',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => IconSetupScreen()));
            },
            icon: const Icon(Icons.arrow_back_ios),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'このIDは他のユーザーに表示されます',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF424242),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '後からの変更はできません',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _controller,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: 'ID',
                      hintText: '半角英数字で入力してください',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.person),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'IDを入力してください';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                        return '半角英数字とアンダースコアのみ使用できます';
                      }
                      if (value.length < 3) {
                        return 'IDは3文字以上で入力してください';
                      }
                      if (value.length > 20) {
                        return 'IDは20文字以下で入力してください';
                      }
                      return null;
                    },
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 20.0),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '登録をすると、利用規約と、プライバシーポリシーに同意したものとみなされます。'
                        'JAMは、アカウントの安全を保ったりなど、プライバシーポリシーに記載されている目的で、'
                        'メールアドレスなど、あなたの連絡先情報を利用することがあります。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _isChecked,
                              onChanged: (bool? value) {
                                setState(() {
                                  _isChecked = value ?? false;
                                  if (!_isChecked) {
                                    _slideValue = 0.0;
                                    _isSliding = false;
                                  }
                                });
                              },
                              activeColor: const Color(0xFF00008b),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '利用規約とプライバシーポリシーに同意する',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF424242),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _isMailPermissionChecked,
                              onChanged: (bool? value) {
                                setState(() {
                                  _isMailPermissionChecked = value ?? true;
                                });
                              },
                              activeColor: const Color(0xFF00008b),
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          const Text(
                            'お知らせメールを受け取る（任意）',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF757575),
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Column(
                    children: [
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          color: _isChecked
                              ? const Color(0xFF00008b)
                              : Colors.grey[300],
                        ),
                        child: Stack(
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 50,
                                thumbShape: SliderThumb(isSliding: _isSliding),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 0),
                                trackShape: const RoundedRectSliderTrackShape(),
                              ),
                              child: Slider(
                                value: _slideValue,
                                onChanged: _isChecked
                                    ? (double value) {
                                        setState(() {
                                          _slideValue = value;
                                          _isSliding = true;
                                        });
                                      }
                                    : null,
                                onChangeEnd: (double value) {
                                  _onSlideComplete();
                                },
                                activeColor: Colors.transparent,
                                inactiveColor: Colors.transparent,
                              ),
                            ),
                            Center(
                              child: Text(
                                'スライドして登録',
                                style: TextStyle(
                                  color: _isChecked
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// カスタムスライダーサムの形状
class SliderThumb extends SliderComponentShape {
  final bool isSliding;

  const SliderThumb({required this.isSliding});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(50.0, 50.0);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    const radius = 25.0;
    canvas.drawCircle(center, radius, paint);

    // スライダーがドラッグされているときのみ矢印を表示
    if (isSliding) {
      final arrowPaint = Paint()
        ..color = const Color(0xFF00008b)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      const arrowSize = 8.0;
      final path = Path();
      path.moveTo(center.dx - arrowSize, center.dy);
      path.lineTo(center.dx + arrowSize, center.dy);
      path.moveTo(center.dx + arrowSize * 0.5, center.dy - arrowSize * 0.5);
      path.lineTo(center.dx + arrowSize, center.dy);
      path.lineTo(center.dx + arrowSize * 0.5, center.dy + arrowSize * 0.5);

      canvas.drawPath(path, arrowPaint);
    } else {
      // 通常時は右矢印アイコンを表示
      final arrowPaint = Paint()
        ..color = const Color(0xFF00008b)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      const arrowSize = 8.0;
      final path = Path();
      path.moveTo(center.dx - arrowSize, center.dy);
      path.lineTo(center.dx + arrowSize, center.dy);
      path.moveTo(center.dx + arrowSize * 0.5, center.dy - arrowSize * 0.5);
      path.lineTo(center.dx + arrowSize, center.dy);
      path.lineTo(center.dx + arrowSize * 0.5, center.dy + arrowSize * 0.5);

      canvas.drawPath(path, arrowPaint);
    }
  }
}
