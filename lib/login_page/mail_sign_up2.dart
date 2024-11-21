import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:parts/login_page/welcome_page/welcome_1.dart';

class SecondSignUpPage extends StatefulWidget {
  final UserCredential userCredential;

  const SecondSignUpPage({Key? key, required this.userCredential})
      : super(key: key);

  @override
  State<SecondSignUpPage> createState() => _SecondSignUpPageState();
}

class _SecondSignUpPageState extends State<SecondSignUpPage>
    with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;

  String userName = '';
  String name = '';
  String id = '';
  DateTime? selectedDate;

  bool _isLoading = false;
  String _language = 'Japanese';

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  final List<AnimationController> _letterControllers = [];
  final List<Animation<double>> _letterAnimations = [];
  bool _titleVisible = false;
  final String titleText = 'JapanAnimeMaps';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting();
    _language = 'Japanese';
    _loadUserLanguage();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    for (int i = 0; i < titleText.length; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );
      _letterControllers.add(controller);
      _letterAnimations.add(
        Tween<double>(begin: 0, end: -10)
            .chain(CurveTween(curve: Curves.easeInOut))
            .animate(controller),
      );
    }

    _controller.forward().then((_) {
      setState(() {
        _titleVisible = true;
      });
      _startLetterAnimations();
    });
  }

  void _startLetterAnimations() {
    for (var i = 0; i < _letterControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _letterControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var controller in _letterControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadUserLanguage() async {
    DocumentSnapshot userDoc = await _firestore
        .collection('users')
        .doc(widget.userCredential.user?.uid)
        .get();

    if (userDoc.exists && userDoc['language'] != null) {
      setState(() {
        _language = userDoc['language'];
      });
    } else {
      setState(() {
        _language = 'Japanese';
      });
    }
  }

  String _formatDate(DateTime date) {
    if (_language == 'Japanese') {
      return DateFormat('yyyy年M月d日', 'ja_JP').format(date);
    } else {
      return DateFormat('MMMM d, yyyy', 'en_US').format(date);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: _language == 'Japanese'
          ? const Locale('ja', 'JP')
          : const Locale('en', 'US'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF7986CB),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF7986CB),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Widget _buildBirthdayField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          TextFormField(
            readOnly: true,
            style: TextStyle(color: Colors.black),
            decoration: InputDecoration(
              labelText: _language == 'Japanese'
                  ? '誕生日を選択 (任意)'
                  : 'Select Birthday (Optional)',
              labelStyle: TextStyle(color: Colors.grey[700]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.cake, color: Color(0xFF7986CB)),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              suffixIcon: IconButton(
                icon: Icon(Icons.calendar_today, color: Color(0xFF7986CB)),
                onPressed: () => _selectDate(context),
              ),
            ),
            controller: TextEditingController(
              text: selectedDate == null ? '' : _formatDate(selectedDate!),
            ),
            onTap: () => _selectDate(context),
          ),
          if (selectedDate != null)
            Positioned(
              right: 48,
              child: IconButton(
                icon: Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    selectedDate = null;
                  });
                },
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
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _language == 'Japanese' ? '追加情報を登録' : 'Sign Up Additional Info',
          style: const TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          DropdownButton<String>(
            value: _language,
            dropdownColor: Colors.white,
            icon: const Icon(Icons.language, color: Color(0xFF00008b)),
            underline: Container(
              height: 2,
              color: Colors.transparent,
            ),
            onChanged: (String? newValue) {
              setState(() {
                _language = newValue!;
              });
            },
            items: <String>['Japanese', 'English']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: const TextStyle(color: Color(0xFF00008b)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SlideTransition(
                        position: _slideAnimation,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < titleText.length; i++)
                              if (_titleVisible)
                                AnimatedBuilder(
                                  animation: _letterAnimations[i],
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset:
                                          Offset(0, _letterAnimations[i].value),
                                      child: Text(
                                        titleText[i],
                                        style: TextStyle(
                                          color: Color(0xFF00008b),
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              else
                                Container(),
                          ],
                        ),
                      ),
                      SizedBox(height: 60),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextFormField(
                          onChanged: (value) {
                            id = value;
                          },
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            labelText: _language == 'Japanese'
                                ? 'ユーザーIDを入力'
                                : 'Enter User ID',
                            labelStyle: TextStyle(color: Colors.grey[700]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon:
                                Icon(Icons.person, color: Color(0xFF7986CB)),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 15),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.singleLineFormatter
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextFormField(
                          onChanged: (value) {
                            name = value;
                          },
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            labelText: _language == 'Japanese'
                                ? '名前を入力 (任意)'
                                : 'Enter Your Name (Optional)',
                            labelStyle: TextStyle(color: Colors.grey[700]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon:
                                Icon(Icons.badge, color: Color(0xFF7986CB)),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 15),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.singleLineFormatter
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      _buildBirthdayField(),
                      SizedBox(height: 40),
                      Container(
                        width: 350.0,
                        height: 50.0,
                        margin: EdgeInsets.symmetric(vertical: 8.0),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7986CB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 3,
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                )
                              : Text(
                                  _language == 'Japanese' ? '登録' : 'Sign Up',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _next() async {
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == 'Japanese'
              ? 'ユーザーIDを入力してください。'
              : 'Please enter a User ID.'),
        ),
      );
      return;
    }

    // Check if ID is already in use
    final QuerySnapshot existingUsers =
        await _firestore.collection('users').where('id', isEqualTo: id).get();

    if (existingUsers.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == 'Japanese'
              ? 'このユーザーIDは既に使用されています。'
              : 'This User ID is already in use.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> userData = {
        'id': id,
        'created_at': FieldValue.serverTimestamp(),
      };

      if (name.isNotEmpty) {
        userData['name'] = name;
      }

      if (selectedDate != null) {
        userData['birthday'] = Timestamp.fromDate(selectedDate!);
      }

      await _firestore
          .collection('users')
          .doc(widget.userCredential.user?.uid)
          .update(userData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == 'Japanese'
              ? '登録が完了しました。'
              : 'Registration completed successfully.'),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => Welcome1(),
        ),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == 'Japanese'
              ? 'エラーが発生しました: $e'
              : 'An error occurred: $e'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
