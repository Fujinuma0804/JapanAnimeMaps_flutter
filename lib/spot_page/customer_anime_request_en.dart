import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'customer_anime_history_en.dart';

class AnimeRequestCustomerFormEn extends StatefulWidget {
  @override
  _AnimeRequestCustomerFormEnState createState() =>
      _AnimeRequestCustomerFormEnState();
}

class _AnimeRequestCustomerFormEnState
    extends State<AnimeRequestCustomerFormEn> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _animeNameController = TextEditingController();
  final TextEditingController _sceneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  XFile? _animeImage;
  XFile? _userImage;
  bool _agreeToTerms = false;
  bool _isLoading = false;

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
          'userEmail': user.email,
          'animeImageUrl': animeImageUrl,
          'userImageUrl': userImageUrl,
          'timestamp': FieldValue.serverTimestamp(),
        });

        _clearForm();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request successfully sent')),
        );
      } catch (e) {
        print('Error submitting form: $e');
        String errorMessage = 'An unexpected error has occurred';
        if (e is FirebaseException) {
          errorMessage = 'Error: ${e.message}';
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
        SnackBar(
            content: Text(
                'Please fill in all required fields and agree to the terms of use.')),
      );
    }
  }

  void _showTermsAndPolicy() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Privacy policy\nTerms of use'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request form',
          style: TextStyle(
            color: Color(0xFF00008b),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.update,
              color: Color(0xFF00008b),
            ),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CustomerRequestHistoryEn()));
            },
          ),
        ],
      ),
      body: Stack(
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
                  decoration: InputDecoration(
                      labelText:
                          'Specific scenes (e.g. episode 3 of season 1)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the scene';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _locationController,
                  decoration:
                      InputDecoration(labelText: 'Sacred place location'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the location of the sacred site';
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
                  decoration:
                      InputDecoration(labelText: 'Longitude (optional)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 15.0),
                ElevatedButton(
                  onPressed: () => _pickImage(false),
                  child: Text(
                    'Upload the image you took (optional)',
                    style: TextStyle(
                      color: Color(0xFF00008b),
                    ),
                  ),
                ),
                const SizedBox(height: 15.0),
                ElevatedButton(
                  onPressed: () => _pickImage(true),
                  child: Text(
                    'Upload anime image (optional)',
                    style: TextStyle(
                      color: Color(0xFF00008b),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _showTermsAndPolicy,
                      child: Text(
                        'You must agree to the privacy policy.',
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
                  onPressed: _agreeToTerms && !_isLoading ? _submitForm : null,
                  child: Text('Send'),
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
      ),
    );
  }
}

const String privacyPolicyText = '''
Privacy policy

1. Information we collect
This application collects the following information when submitting an anime request form:
- Email address
- Information about anime (anime name, scene, sacred place location)
- Location information (optional)
- Uploaded image

2. Purpose of use of information
The information we collect will be used for the following purposes:
- Processing and managing anime requests
- Improving services and developing new features
- Providing user support

3. Sharing information
The collected personal information, such as user name and image, will be made public when a sacred place is published.
No other personal information will be shared with third parties unless required by law.

4. Data protection
Our Application takes appropriate security measures to protect the information we collect.

5. User rights
Users have the right to request access to, correction and deletion of their personal information.

6. Changes to privacy policy
This privacy policy is subject to change. If there are any changes, we will notify you within the application.

7. Contact
If you have any questions or concerns regarding privacy, please contact us at support@infomapanime.click.

Last updated date：August 13, 2024
''';
