import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:parts/login_page/welcome_page/welcome_1.dart';

class SecondSignUpPage extends StatefulWidget {
  final UserCredential userCredential;

  const SecondSignUpPage({Key? key, required this.userCredential})
      : super(key: key);

  @override
  State<SecondSignUpPage> createState() => _SecondSignUpPageState();
}

class _SecondSignUpPageState extends State<SecondSignUpPage> {
  final _firestore = FirebaseFirestore.instance;

  String userName = '';
  String name = '';
  String id = '';
  DateTime? selectedDate;

  bool _isLoading = false;
  String _language = 'Japanese';

  @override
  void initState() {
    super.initState();
    _language = 'Japanese';
    _loadUserLanguage();
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
      // ユーザーのドキュメントが存在しないか、言語設定がない場合、日本語をデフォルトとする
      setState(() {
        _language = 'Japanese';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate)
      setState(() {
        selectedDate = picked;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _language == '日本語' ? '追加情報を登録' : 'Sign Up Additional Info',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          DropdownButton<String>(
            value: _language,
            dropdownColor: Colors.black,
            icon: const Icon(Icons.language, color: Colors.white),
            underline: Container(
              height: 2,
              color: Colors.transparent,
            ),
            onChanged: (String? newValue) {
              setState(() {
                _language = newValue!;
              });
            },
            items: <String>['日本語', 'English']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: SizedBox(
                            width: 350.0,
                            height: 45.0,
                            child: TextFormField(
                              onChanged: (value) {
                                id = value;
                              },
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: _language == '日本語'
                                    ? 'ユーザーIDを入力'
                                    : 'Enter User ID',
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                ),
                                border: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                  ),
                                ),
                                enabledBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              textAlign: TextAlign.left,
                              inputFormatters: [
                                FilteringTextInputFormatter.singleLineFormatter
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        Center(
                          child: SizedBox(
                            width: 350.0,
                            height: 45.0,
                            child: TextFormField(
                              onChanged: (value) {
                                name = value;
                              },
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: _language == '日本語'
                                    ? '名前を入力 (任意)'
                                    : 'Enter Your Name (Optional)',
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                ),
                                border: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                  ),
                                ),
                                enabledBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              textAlign: TextAlign.left,
                              inputFormatters: [
                                FilteringTextInputFormatter.singleLineFormatter
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        Center(
                          child: SizedBox(
                            width: 350.0,
                            height: 45.0,
                            child: GestureDetector(
                              onTap: () => _selectDate(context),
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: _language == '日本語'
                                        ? '誕生日を選択 (任意)'
                                        : 'Select Birthday (Optional)',
                                    labelStyle: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    border: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white,
                                      ),
                                    ),
                                    enabledBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white,
                                      ),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.left,
                                  controller: TextEditingController(
                                    text: selectedDate == null
                                        ? ''
                                        : DateFormat('yyyy-MM-dd')
                                            .format(selectedDate!),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 50.0),
                        SizedBox(
                          height: 50.0,
                          width: 200.0,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white,
                              ),
                              backgroundColor: Colors.transparent,
                            ),
                            onPressed: _isLoading ? null : _next,
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  )
                                : Text(
                                    _language == '日本語' ? '登録' : 'Sign Up',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 25.0),
                        SizedBox(
                          height: MediaQuery.of(context).viewInsets.bottom,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _next() async {
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == '日本語'
              ? 'ユーザーIDを入力してください。'
              : 'Please enter a User ID.'),
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
        userData['birthday'] = selectedDate;
      }

      await _firestore
          .collection('users')
          .doc(widget.userCredential.user?.uid)
          .update(userData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_language == '日本語'
              ? '登録が完了しました。'
              : 'Registration completed successfully.'),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Welcome1(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _language == '日本語' ? 'エラーが発生しました: $e' : 'An error occurred: $e'),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
