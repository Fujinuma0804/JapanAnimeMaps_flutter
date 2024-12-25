import 'package:flutter/material.dart';

import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  late TextEditingController _displayNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _initControllers(UserProfile profile) {
    _displayNameController.text = profile.displayName ?? '';
    _emailController.text = profile.email ?? '';
    _phoneController.text = profile.phoneNumber ?? '';
    _addressController.text = profile.address ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'プロフィール',
          style: TextStyle(
            color: Color(0xFF00008B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
            },
          ),
        ],
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _userService.getUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data!;
          if (!_isEditing) {
            _initControllers(profile);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(profile),
                  const SizedBox(height: 24),
                  _buildProfileForm(),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _isEditing ? _buildSaveButton() : null,
    );
  }

  Widget _buildProfileHeader(UserProfile profile) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: profile.photoUrl != null
                ? NetworkImage(profile.photoUrl!)
                : null,
            child: profile.photoUrl == null
                ? const Icon(Icons.person, size: 50, color: Colors.grey)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            profile.displayName ?? 'ゲスト',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '所持コイン: ${profile.coins} P',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF00008B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _displayNameController,
          enabled: _isEditing,
          decoration: const InputDecoration(
            labelText: '表示名',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '表示名を入力してください';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          enabled: _isEditing,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'メールアドレスを入力してください';
            }
            if (!value.contains('@')) {
              return '有効なメールアドレスを入力してください';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          enabled: _isEditing,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: '電話番号',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '電話番号を入力してください';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          enabled: _isEditing,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '住所',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '住所を入力してください';
            }
            return null;
          },
        ),
        if (!_isEditing) ...[
          const SizedBox(height: 32),
          _buildDangerZone(),
        ],
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00008B),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '保存',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '危険な操作',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _showDeleteAccountDialog,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('アカウントを削除'),
        ),
      ],
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _userService.updateUserProfile(
        displayName: _displayNameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
        address: _addressController.text,
      );

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールを更新しました')),
      );

      setState(() => _isEditing = false);
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウントを削除'),
        content: const Text(
          'アカウントを削除すると、すべてのデータが完全に削除され、復元できなくなります。\n\nこの操作は取り消せません。本当に続行しますか？',
        ),
        actions: [
          TextButton(
            child: const Text('キャンセル'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text(
              '削除',
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _userService.deleteAccount();
        // ignore: use_build_context_synchronously
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }
}
