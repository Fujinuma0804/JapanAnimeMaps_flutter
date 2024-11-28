import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parts/post_page/timeline_screen.dart';

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
            .update({'id': newId});

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const TimelineScreen()),
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
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text(
                  'このIDは他のユーザーに表示されます\n'
                  '後からの変更はできません。',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(
                  height: 32,
                ),
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
                const SizedBox(
                  height: 20.0,
                ),
                Center(
                  child: Text(
                    '登録をすると、利用規約と、プライバシーポリシーに同意したものとみなされます。'
                    'JAMは、アカウントの安全を保ったりなど、プライバシーポリシーに記載されている目的で、'
                    'メールアドレスなど、あなたの連絡先情報を利用することがあります。',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveId,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF00008b),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '登録',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TimelineScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '今は設定しない',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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
