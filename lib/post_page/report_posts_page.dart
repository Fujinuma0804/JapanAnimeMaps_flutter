import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportPostsPage extends StatefulWidget {
  final String communityId;
  final String userHandle; // communityNameをuserHandleに変更

  const ReportPostsPage({
    Key? key,
    required this.communityId,
    required this.userHandle, // パラメータ名を変更
  }) : super(key: key);

  @override
  State<ReportPostsPage> createState() => _ReportPostsPageState();
}

class _ReportPostsPageState extends State<ReportPostsPage> {
  final _reportReasonController = TextEditingController();
  List<String> _selectedReasons = [];
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _currentUserEmail;
  bool _isSliding = false;
  double _slidePosition = 0.0;
  final double _slideThreshold = 0.8;

  final List<String> _reportReasons = [
    '不適切なコンテンツ',
    'スパムまたは詐欺',
    'ハラスメント',
    '著作権侵害',
    'その他',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (mounted) {
          setState(() {
            _currentUserEmail = user.email;
            _isLoading = false;
          });
        }
      } else {
        _handleError('ユーザーが見つかりません');
      }
    } catch (e) {
      _handleError('ユーザー情報の取得に失敗しました');
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _reportReasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('通報理由を選択してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('ユーザーが見つかりません');
      }

      await FirebaseFirestore.instance.collection('reports').add({
        'communityId': widget.communityId,
        'userHandle': widget.userHandle, // フィールド名を変更
        'reporterId': user.uid,
        'reporterEmail': user.email,
        'reasons': _selectedReasons,
        'additionalDetails': _reportReasonController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        await _showSuccessDialog();
      }
    } catch (e) {
      _handleSubmissionError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _slidePosition = 0.0;
          _isSliding = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Text(
              '通報を受け付けました',
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('ご協力ありがとうございます。'),
                SizedBox(height: 8),
                Text('調査のためのみに運営が利用します。'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF00008b)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleSubmissionError(dynamic error) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text(
              '通報の送信に失敗しました',
              style: TextStyle(
                color: Color(0xFF00008b),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              '${error.toString()}\n後ほど再度お試しください。',
              style: const TextStyle(color: Color(0xFF00008b)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF00008b)),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildSlideButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: const Color(0xFFEEEEEE),
      ),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: MediaQuery.of(context).size.width * _slidePosition,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: const Color(0xFF00008b),
            ),
          ),
          GestureDetector(
            onHorizontalDragStart: (_) {
              setState(() => _isSliding = true);
            },
            onHorizontalDragUpdate: (details) {
              if (_isSliding && !_isSubmitting) {
                setState(() {
                  _slidePosition = (_slidePosition +
                          details.delta.dx / MediaQuery.of(context).size.width)
                      .clamp(0.0, 1.0);
                });
              }
            },
            onHorizontalDragEnd: (_) {
              if (_slidePosition > _slideThreshold) {
                _submitReport();
              } else {
                setState(() {
                  _slidePosition = 0.0;
                  _isSliding = false;
                });
              }
            },
            child: Container(
              width: double.infinity,
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isSubmitting
                          ? const Color(0xFF00008b).withOpacity(0.5)
                          : const Color(0xFF00008b),
                    ),
                    child: _isSubmitting
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isSubmitting ? '送信中...' : '右にスライドして通報',
                    style: const TextStyle(
                      color: Color(0xFF00008b),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'コミュニティを通報',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF00008b)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00008b),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              labelText: '通報対象',
                              labelStyle: const TextStyle(color: Colors.black),
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                            ),
                            controller: TextEditingController(
                                text:
                                    widget.userHandle), // userHandleを表示するように変更
                            enabled: false,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            decoration: InputDecoration(
                              labelText: '通報者',
                              labelStyle: const TextStyle(color: Colors.black),
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                            ),
                            controller:
                                TextEditingController(text: _currentUserEmail),
                            enabled: false,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '通報理由を選択してください：',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._reportReasons.map((reason) => CheckboxListTile(
                                title: Text(
                                  reason,
                                  style: const TextStyle(
                                    color: Colors.black,
                                  ),
                                ),
                                value: _selectedReasons.contains(reason),
                                onChanged: (value) {
                                  setState(() {
                                    if (value ?? false) {
                                      _selectedReasons.add(reason);
                                    } else {
                                      _selectedReasons.remove(reason);
                                    }
                                  });
                                },
                                activeColor: const Color(0xFF00008b),
                              )),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _reportReasonController,
                            decoration: const InputDecoration(
                              labelText: '詳細な理由（任意）',
                              labelStyle: TextStyle(color: Colors.black),
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.black),
                              ),
                            ),
                            maxLines: 3,
                            style: const TextStyle(color: Color(0xFF00008b)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00008b),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_outline,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'コミュニティ管理者やユーザーにあなたの情報が知らされることはありません。',
                                  style: TextStyle(
                                    color: Color(0xFF00008b),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSlideButton(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
