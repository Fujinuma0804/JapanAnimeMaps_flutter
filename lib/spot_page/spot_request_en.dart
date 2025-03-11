import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:parts/login_page/sign_up.dart';

import 'customer_anime_history.dart';

class AnimeRequestCustomerFormEn extends StatefulWidget {
  @override
  _AnimeRequestCustomerFormEnState createState() =>
      _AnimeRequestCustomerFormEnState();
}

class _AnimeRequestCustomerFormEnState extends State<AnimeRequestCustomerFormEn> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _animeNameController = TextEditingController();
  final TextEditingController _sceneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _referenceLinkController =
  TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  XFile? _animeImage;
  XFile? _userImage;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _isAuthorizedUser = false;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  void _checkUserStatus() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _isAuthorizedUser = user != null && !user.isAnonymous;
    });
  }

  Future<void> _pickImage(bool isAnimeImage) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (isAnimeImage) {
        _animeImage = image;
      } else {
        _userImage = image;
      }
    });
  }

  void _clearForm() {
    _animeNameController.clear();
    _sceneController.clear();
    _locationController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _referenceLinkController.clear();
    _notesController.clear();
    setState(() {
      _animeImage = null;
      _userImage = null;
      _agreeToTerms = false;
    });
  }

  Future<String> _uploadImage(XFile image) async {
    Uint8List imageBytes = await image.readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);

    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

    img.Image resizedImage = img.copyResize(originalImage, width: 1024);
    List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 85);

    Uint8List uint8List = Uint8List.fromList(compressedBytes);

    final ref = FirebaseStorage.instance
        .ref()
        .child('images/${DateTime.now().toIso8601String()}.jpg');
    final uploadTask =
    ref.putData(uint8List, SettableMetadata(contentType: 'image/jpeg'));
    final snapshot = await uploadTask.whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate() && _agreeToTerms) {
      setState(() {
        _isLoading = true;
      });
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        String? animeImageUrl;
        String? userImageUrl;

        if (_animeImage != null) {
          animeImageUrl = await _uploadImage(_animeImage!);
        }
        if (_userImage != null) {
          userImageUrl = await _uploadImage(_userImage!);
        }

        await FirebaseFirestore.instance
            .collection('customer_animerequest')
            .add({
          'animeName': _animeNameController.text,
          'scene': _sceneController.text,
          'location': _locationController.text,
          'latitude': _latitudeController.text,
          'longitude': _longitudeController.text,
          'referenceLink': _referenceLinkController.text,
          'notes': _notesController.text,
          'userEmail': user.email,
          'animeImageUrl': animeImageUrl,
          'userImageUrl': userImageUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'request',
        });

        _clearForm();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request submitted successfully.')),
        );
      } catch (e) {
        print('Error submitting form: $e');
        String errorMessage = 'An unexpected error occurred.';
        if (e is FirebaseException) {
          errorMessage = 'Firebase error: ${e.message}';
        } else if (e is Exception) {
          errorMessage = 'Error: ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields and agree to the terms.')),
      );
    }
  }

  void _showTermsAndPolicy() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Privacy Policy\nTerms of Use'),
          content: SingleChildScrollView(
            child: Text(privacyPolicyText),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToSignUp() {
    print('Navigating to sign up page');
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => SignUpPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Request Form',
            style: TextStyle(
              color: Color(0xFF00008b),
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: _isAuthorizedUser
              ? [
            IconButton(
              icon: Icon(
                Icons.update,
                color: Color(0xFF00008b),
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CustomerRequestHistory()));
              },
            ),
          ]
              : null,
        ),
        body: _isAuthorizedUser
            ? Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(16.0),
                children: <Widget>[
                  TextFormField(
                    controller: _animeNameController,
                    decoration: InputDecoration(labelText: 'Anime Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the anime name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _sceneController,
                    decoration:
                    InputDecoration(labelText: 'Specific Scene (e.g., Season 1 Episode 3)'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the scene';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(labelText: 'Location'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the location';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _latitudeController,
                    decoration: InputDecoration(labelText: 'Latitude (optional)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _longitudeController,
                    decoration: InputDecoration(labelText: 'Longitude (optional)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _referenceLinkController,
                    decoration: InputDecoration(labelText: 'Reference Link (optional)'),
                    keyboardType: TextInputType.url,
                  ),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(labelText: 'Notes (optional)'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 15.0),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(false),
                    icon: Icon(
                      _userImage != null
                          ? Icons.check_circle
                          : Icons.add_photo_alternate,
                      color: _userImage != null
                          ? Colors.green
                          : Color(0xFF00008b),
                    ),
                    label: Text(
                      _userImage != null
                          ? 'Change Your Photo'
                          : 'Upload Your Photo (optional)',
                      style: TextStyle(
                        color: Color(0xFF00008b),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      _userImage != null ? Colors.grey[200] : null,
                    ),
                  ),
                  const SizedBox(height: 15.0),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(true),
                    icon: Icon(
                      _animeImage != null
                          ? Icons.check_circle
                          : Icons.add_photo_alternate,
                      color: _animeImage != null
                          ? Colors.green
                          : Color(0xFF00008b),
                    ),
                    label: Text(
                      _animeImage != null
                          ? 'Change Anime Image'
                          : 'Upload Anime Image (optional)',
                      style: TextStyle(
                        color: Color(0xFF00008b),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      _animeImage != null ? Colors.grey[200] : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _showTermsAndPolicy,
                        child: Text(
                          'Agreement to Privacy Policy is required.',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: Color(0xFF00008b),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (bool? value) {
                          setState(() {
                            _agreeToTerms = value!;
                          });
                        },
                      ),
                      Text('I agree'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed:
                    _agreeToTerms && !_isLoading ? _submitForm : null,
                    child: Text('Submit'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Color(0xFF00008b),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        )
            : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'You need to be logged in to use this form.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed: _navigateToSignUp,
                  child: Text(
                    'Sign Up Here',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFF00008b),
                    padding: EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    textStyle: TextStyle(
                      fontSize: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                )
              ],
            )));
  }
}

const String privacyPolicyText = '''
Privacy Policy

1. Information We Collect
This application collects the following information when submitting anime requests:
- Email address
- Anime information (anime name, scene, location)
- Location information (optional)
- Uploaded images

2. How We Use Your Information
The collected information is used for the following purposes:
- Processing and managing anime requests
- Improving our service and developing new features
- Providing user support

3. Information Sharing
When a location is published, user names and images may be made public.
Other personal information will not be shared with third parties except as required by law.

4. Data Protection
This application implements appropriate security measures to protect the collected information.

5. User Rights
Users have the right to request access to, correction of, or deletion of their personal information.

6. Changes to Privacy Policy
This Privacy Policy may be changed. Any changes will be notified within the application.

7. Contact Us
For privacy-related questions or inquiries, please contact us at japananimemaps@jam-info.com.

Last updated: November 7, 2024
''';