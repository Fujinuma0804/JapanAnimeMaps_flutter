// import 'dart:typed_data';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/material.dart';
// import 'package:image/image.dart' as img;
// import 'package:image_picker/image_picker.dart';
// import 'package:parts/login_page/sign_up.dart';

// import 'customer_anime_history.dart';

// class AnimeRequestCustomerForm extends StatefulWidget {
//   @override
//   _AnimeRequestCustomerFormState createState() =>
//       _AnimeRequestCustomerFormState();
// }

// class _AnimeRequestCustomerFormState extends State<AnimeRequestCustomerForm> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _animeNameController = TextEditingController();
//   final TextEditingController _sceneController = TextEditingController();
//   final TextEditingController _locationController = TextEditingController();
//   final TextEditingController _latitudeController = TextEditingController();
//   final TextEditingController _longitudeController = TextEditingController();
//   final TextEditingController _referenceLinkController =
//       TextEditingController();
//   final TextEditingController _notesController = TextEditingController();

//   XFile? _animeImage;
//   XFile? _userImage;
//   bool _agreeToTerms = false;
//   bool _isLoading = false;
//   bool _isAuthorizedUser = false;

//   @override
//   void initState() {
//     super.initState();
//     _checkUserStatus();
//   }

//   void _checkUserStatus() {
//     final user = FirebaseAuth.instance.currentUser;
//     setState(() {
//       _isAuthorizedUser = user != null && !user.isAnonymous;
//     });
//   }

//   Future<void> _pickImage(bool isAnimeImage) async {
//     final ImagePicker _picker = ImagePicker();
//     final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
//     setState(() {
//       if (isAnimeImage) {
//         _animeImage = image;
//       } else {
//         _userImage = image;
//       }
//     });
//   }

//   void _clearForm() {
//     _animeNameController.clear();
//     _sceneController.clear();
//     _locationController.clear();
//     _latitudeController.clear();
//     _longitudeController.clear();
//     _referenceLinkController.clear();
//     _notesController.clear();
//     setState(() {
//       _animeImage = null;
//       _userImage = null;
//       _agreeToTerms = false;
//     });
//   }

//   Future<String> _uploadImage(XFile image) async {
//     Uint8List imageBytes = await image.readAsBytes();
//     img.Image? originalImage = img.decodeImage(imageBytes);

//     if (originalImage == null) {
//       throw Exception('Failed to decode image');
//     }

//     img.Image resizedImage = img.copyResize(originalImage, width: 1024);
//     List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 85);

//     Uint8List uint8List = Uint8List.fromList(compressedBytes);

//     final ref = FirebaseStorage.instance
//         .ref()
//         .child('images/${DateTime.now().toIso8601String()}.jpg');
//     final uploadTask =
//         ref.putData(uint8List, SettableMetadata(contentType: 'image/jpeg'));
//     final snapshot = await uploadTask.whenComplete(() {});
//     return await snapshot.ref.getDownloadURL();
//   }

//   void _submitForm() async {
//     if (_formKey.currentState!.validate() && _agreeToTerms) {
//       setState(() {
//         _isLoading = true;
//       });
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user == null) throw Exception('User not logged in');

//         String? animeImageUrl;
//         String? userImageUrl;

//         if (_animeImage != null) {
//           animeImageUrl = await _uploadImage(_animeImage!);
//         }
//         if (_userImage != null) {
//           userImageUrl = await _uploadImage(_userImage!);
//         }

//         await FirebaseFirestore.instance
//             .collection('customer_animerequest')
//             .add({
//           'animeName': _animeNameController.text,
//           'scene': _sceneController.text,
//           'location': _locationController.text,
//           'latitude': _latitudeController.text,
//           'longitude': _longitudeController.text,
//           'referenceLink': _referenceLinkController.text,
//           'notes': _notesController.text,
//           'userEmail': user.email,
//           'animeImageUrl': animeImageUrl,
//           'userImageUrl': userImageUrl,
//           'timestamp': FieldValue.serverTimestamp(),
//           'status': 'request',
//         });

//         _clearForm();

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('リクエストが正常に送信されました。')),
//         );
//       } catch (e) {
//         print('Error submitting form: $e');
//         String errorMessage = '予期せぬエラーが発生しました。';
//         if (e is FirebaseException) {
//           errorMessage = 'Firebase エラー: ${e.message}';
//         } else if (e is Exception) {
//           errorMessage = 'エラー: ${e.toString()}';
//         }
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(errorMessage)),
//         );
//       } finally {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('すべての必須項目を入力し、利用規約に同意してください。')),
//       );
//     }
//   }

//   void _showTermsAndPolicy() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('プライバシーポリシー\n利用規約'),
//           content: SingleChildScrollView(
//             child: Text(privacyPolicyText),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('閉じる'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _navigateToSignUp() {
//     print('会員登録ページへ遷移');
//     Navigator.push(
//         context, MaterialPageRoute(builder: (context) => SignUpPage()));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           title: Text(
//             'リクエストフォーム',
//             style: TextStyle(
//               color: Color(0xFF00008b),
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           actions: _isAuthorizedUser
//               ? [
//                   IconButton(
//                     icon: Icon(
//                       Icons.update,
//                       color: Color(0xFF00008b),
//                     ),
//                     onPressed: () {
//                       Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                               builder: (context) => CustomerRequestHistory()));
//                     },
//                   ),
//                 ]
//               : null,
//         ),
//         body: _isAuthorizedUser
//             ? Stack(
//                 children: [
//                   Form(
//                     key: _formKey,
//                     child: ListView(
//                       padding: EdgeInsets.all(16.0),
//                       children: <Widget>[
//                         TextFormField(
//                           controller: _animeNameController,
//                           decoration: InputDecoration(labelText: 'アニメ名'),
//                           validator: (value) {
//                             if (value == null || value.isEmpty) {
//                               return 'アニメ名を入力してください';
//                             }
//                             return null;
//                           },
//                         ),
//                         TextFormField(
//                           controller: _sceneController,
//                           decoration:
//                               InputDecoration(labelText: '具体的なシーン（シーズン1の3話など）'),
//                           validator: (value) {
//                             if (value == null || value.isEmpty) {
//                               return 'シーンを入力してください';
//                             }
//                             return null;
//                           },
//                         ),
//                         TextFormField(
//                           controller: _locationController,
//                           decoration: InputDecoration(labelText: '聖地の場所'),
//                           validator: (value) {
//                             if (value == null || value.isEmpty) {
//                               return '聖地の場所を入力してください';
//                             }
//                             return null;
//                           },
//                         ),
//                         TextFormField(
//                           controller: _latitudeController,
//                           decoration: InputDecoration(labelText: '緯度（任意）'),
//                           keyboardType: TextInputType.number,
//                         ),
//                         TextFormField(
//                           controller: _longitudeController,
//                           decoration: InputDecoration(labelText: '経度（任意）'),
//                           keyboardType: TextInputType.number,
//                         ),
//                         TextFormField(
//                           controller: _referenceLinkController,
//                           decoration: InputDecoration(labelText: '参照リンク（任意）'),
//                           keyboardType: TextInputType.url,
//                         ),
//                         TextFormField(
//                           controller: _notesController,
//                           decoration: InputDecoration(labelText: '備考（任意）'),
//                           maxLines: 3,
//                         ),
//                         const SizedBox(height: 15.0),
//                         ElevatedButton.icon(
//                           onPressed: () => _pickImage(false),
//                           icon: Icon(
//                             _userImage != null
//                                 ? Icons.check_circle
//                                 : Icons.add_photo_alternate,
//                             color: _userImage != null
//                                 ? Colors.green
//                                 : Color(0xFF00008b),
//                           ),
//                           label: Text(
//                             _userImage != null
//                                 ? '撮影した画像を変更'
//                                 : '撮影した画像をアップロード（任意）',
//                             style: TextStyle(
//                               color: Color(0xFF00008b),
//                             ),
//                           ),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor:
//                                 _userImage != null ? Colors.grey[200] : null,
//                           ),
//                         ),
//                         const SizedBox(height: 15.0),
//                         ElevatedButton.icon(
//                           onPressed: () => _pickImage(true),
//                           icon: Icon(
//                             _animeImage != null
//                                 ? Icons.check_circle
//                                 : Icons.add_photo_alternate,
//                             color: _animeImage != null
//                                 ? Colors.green
//                                 : Color(0xFF00008b),
//                           ),
//                           label: Text(
//                             _animeImage != null
//                                 ? 'アニメ画像を変更'
//                                 : 'アニメ画像をアップロード（任意）',
//                             style: TextStyle(
//                               color: Color(0xFF00008b),
//                             ),
//                           ),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor:
//                                 _animeImage != null ? Colors.grey[200] : null,
//                           ),
//                         ),
//                         const SizedBox(height: 20),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             TextButton(
//                               onPressed: _showTermsAndPolicy,
//                               child: Text(
//                                 'プライバシーポリシーへの同意が必要です。',
//                                 style: TextStyle(
//                                   decoration: TextDecoration.underline,
//                                   color: Color(0xFF00008b),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Checkbox(
//                               value: _agreeToTerms,
//                               onChanged: (bool? value) {
//                                 setState(() {
//                                   _agreeToTerms = value!;
//                                 });
//                               },
//                             ),
//                             Text('同意します'),
//                           ],
//                         ),
//                         const SizedBox(height: 20),
//                         ElevatedButton(
//                           onPressed:
//                               _agreeToTerms && !_isLoading ? _submitForm : null,
//                           child: Text('送信'),
//                           style: ElevatedButton.styleFrom(
//                             foregroundColor: Colors.white,
//                             backgroundColor: Color(0xFF00008b),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   if (_isLoading)
//                     Container(
//                       color: Colors.black.withOpacity(0.5),
//                       child: Center(
//                         child: CircularProgressIndicator(),
//                       ),
//                     ),
//                 ],
//               )
//             : Center(
//                 child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text(
//                     'このフォームを使用するにはログインが必要です。',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   SizedBox(
//                     height: 20,
//                   ),
//                   ElevatedButton(
//                     onPressed: _navigateToSignUp,
//                     child: Text(
//                       '会員登録はこちら',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       foregroundColor: Colors.white,
//                       backgroundColor: Color(0xFF00008b),
//                       padding: EdgeInsets.symmetric(
//                         horizontal: 30,
//                         vertical: 15,
//                       ),
//                       textStyle: TextStyle(
//                         fontSize: 18,
//                       ),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(30),
//                       ),
//                       elevation: 5,
//                     ),
//                   )
//                 ],
//               )));
//   }
// }

// const String privacyPolicyText = '''
// プライバシーポリシー

// 1. 収集する情報
// 当アプリケーションは、アニメリクエストフォームの提出に際し、以下の情報を収集します：
// - メールアドレス
// - アニメに関する情報（アニメ名、シーン、聖地の場所）
// - 位置情報（任意）
// - アップロードされた画像

// 2. 情報の使用目的
// 収集した情報は以下の目的で使用されます：
// - アニメリクエストの処理と管理
// - サービスの改善と新機能の開発
// - ユーザーサポートの提供

// 3. 情報の共有
// 収集した個人情報は、聖地が掲載される場合にはユーザ名や画像が公開されます。
// それ以外の個人情報については法律で定められた場合を除き、第三者と共有されることはありません。

// 4. データの保護
// 当アプリケーションは、収集した情報を保護するために適切なセキュリティ対策を講じています。

// 5. ユーザーの権利
// ユーザーは自身の個人情報へのアクセス、訂正、削除を要求する権利を有しています。

// 6. プライバシーポリシーの変更
// 本プライバシーポリシーは変更される可能性があります。変更がある場合は、アプリケーション内で通知します。

// 7. お問い合わせ
// プライバシーに関するご質問やお問い合わせは、japananimemaps@jam-info.comまでご連絡ください。

// 最終更新日：2024年11月7日
// ''';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parts/bloc/Customer_requestformbloc/Customer_requestformbloc.dart';
import 'package:parts/login_page/sign_up.dart';

import 'customer_anime_history.dart';

class AnimeRequestCustomerForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AnimeRequestBloc()..add(CheckUserStatusEvent()),
      child: _AnimeRequestCustomerFormContent(),
    );
  }
}

class _AnimeRequestCustomerFormContent extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();

  void _showTermsAndPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('プライバシーポリシー\n利用規約'),
          content: SingleChildScrollView(
            child: Text(privacyPolicyText),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('閉じる'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToSignUp(BuildContext context) {
    print('会員登録ページへ遷移');
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => SignUpPage()));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AnimeRequestBloc, AnimeRequestState>(
      listener: (context, state) {
        if (state is AnimeRequestError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error)),
          );
        }
        if (state is AnimeRequestSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: BlocBuilder<AnimeRequestBloc, AnimeRequestState>(
        builder: (context, state) {
          if (state is! AnimeRequestFormState) {
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  'リクエストフォーム',
                  style: TextStyle(
                    color: Color(0xFF00008b),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final formState = state;
          final bloc = context.read<AnimeRequestBloc>();

          return Scaffold(
            appBar: AppBar(
              title: Text(
                'リクエストフォーム',
                style: TextStyle(
                  color: Color(0xFF00008b),
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: formState.isAuthorizedUser
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
                                  builder: (context) =>
                                      CustomerRequestHistory()));
                        },
                      ),
                    ]
                  : null,
            ),
            body: formState.isAuthorizedUser
                ? Stack(
                    children: [
                      Form(
                        key: _formKey,
                        child: ListView(
                          padding: EdgeInsets.all(16.0),
                          children: <Widget>[
                            TextFormField(
                              initialValue: formState.formData['animeName'],
                              decoration: InputDecoration(labelText: 'アニメ名'),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'アニメ名を入力してください';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                bloc.add(UpdateFormFieldEvent(
                                    fieldName: 'animeName', value: value));
                              },
                            ),
                            TextFormField(
                              initialValue: formState.formData['scene'],
                              decoration: InputDecoration(
                                  labelText: '具体的なシーン（シーズン1の3話など）'),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'シーンを入力してください';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                bloc.add(UpdateFormFieldEvent(
                                    fieldName: 'scene', value: value));
                              },
                            ),
                            TextFormField(
                              initialValue: formState.formData['location'],
                              decoration: InputDecoration(labelText: '聖地の場所'),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '聖地の場所を入力してください';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                bloc.add(UpdateFormFieldEvent(
                                    fieldName: 'location', value: value));
                              },
                            ),
                            TextFormField(
                              initialValue: formState.formData['latitude'],
                              decoration: InputDecoration(labelText: '緯度（任意）'),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                bloc.add(UpdateFormFieldEvent(
                                    fieldName: 'latitude', value: value));
                              },
                            ),
                            TextFormField(
                              initialValue: formState.formData['longitude'],
                              decoration: InputDecoration(labelText: '経度（任意）'),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                bloc.add(UpdateFormFieldEvent(
                                    fieldName: 'longitude', value: value));
                              },
                            ),
                            TextFormField(
                              initialValue: formState.formData['referenceLink'],
                              decoration:
                                  InputDecoration(labelText: '参照リンク（任意）'),
                              keyboardType: TextInputType.url,
                              onChanged: (value) {
                                bloc.add(UpdateFormFieldEvent(
                                    fieldName: 'referenceLink', value: value));
                              },
                            ),
                            TextFormField(
                              initialValue: formState.formData['notes'],
                              decoration: InputDecoration(labelText: '備考（任意）'),
                              maxLines: 3,
                              onChanged: (value) {
                                bloc.add(UpdateFormFieldEvent(
                                    fieldName: 'notes', value: value));
                              },
                            ),
                            const SizedBox(height: 15.0),

                            // User Image Upload Section
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => bloc.add(
                                        PickImageEvent(isAnimeImage: false)),
                                    icon: Icon(
                                      formState.userImage != null
                                          ? Icons.check_circle
                                          : Icons.add_photo_alternate,
                                      color: formState.userImage != null
                                          ? Colors.green
                                          : Color(0xFF00008b),
                                    ),
                                    label: Text(
                                      formState.userImage != null
                                          ? '撮影画像を変更'
                                          : '撮影画像をアップロード（任意）',
                                      style: TextStyle(
                                        color: Color(0xFF00008b),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          formState.userImage != null
                                              ? Colors.grey[200]
                                              : null,
                                    ),
                                  ),
                                ),
                                if (formState.userImage != null)
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => bloc.add(
                                        RemoveImageEvent(isAnimeImage: false)),
                                  ),
                              ],
                            ),

                            // Anime Image Upload Section
                            const SizedBox(height: 15.0),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => bloc.add(
                                        PickImageEvent(isAnimeImage: true)),
                                    icon: Icon(
                                      formState.animeImage != null
                                          ? Icons.check_circle
                                          : Icons.add_photo_alternate,
                                      color: formState.animeImage != null
                                          ? Colors.green
                                          : Color(0xFF00008b),
                                    ),
                                    label: Text(
                                      formState.animeImage != null
                                          ? 'アニメ画像を変更'
                                          : 'アニメ画像をアップロード（任意）',
                                      style: TextStyle(
                                        color: Color(0xFF00008b),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          formState.animeImage != null
                                              ? Colors.grey[200]
                                              : null,
                                    ),
                                  ),
                                ),
                                if (formState.animeImage != null)
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => bloc.add(
                                        RemoveImageEvent(isAnimeImage: true)),
                                  ),
                              ],
                            ),

                            // Upload Progress Indicator
                            if (formState.imageUploadProgress > 0 &&
                                formState.imageUploadProgress < 1)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  children: [
                                    LinearProgressIndicator(
                                      value: formState.imageUploadProgress,
                                      backgroundColor: Colors.grey[300],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF00008b)),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'アップロード中: ${(formState.imageUploadProgress * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () => _showTermsAndPolicy(context),
                                  child: Text(
                                    'プライバシーポリシーへの同意が必要です。',
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
                                  value: formState.agreeToTerms,
                                  onChanged: (bool? value) {
                                    if (value != null) {
                                      bloc.add(UpdateTermsAgreementEvent(
                                          agreed: value));
                                    }
                                  },
                                ),
                                Text('同意します'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: formState.agreeToTerms &&
                                      formState.formValid &&
                                      !formState.isLoading &&
                                      !formState.isSubmitting
                                  ? () {
                                      if (_formKey.currentState!.validate()) {
                                        bloc.add(SubmitFormEvent());
                                      }
                                    }
                                  : null,
                              child: formState.isSubmitting
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('送信中...'),
                                      ],
                                    )
                                  : Text('送信'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Color(0xFF00008b),
                                minimumSize: Size(double.infinity, 50),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (formState.isLoading)
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
                        'このフォームを使用するにはログインが必要です。',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      ElevatedButton(
                        onPressed: () => _navigateToSignUp(context),
                        child: Text(
                          '会員登録はこちら',
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
                  )),
          );
        },
      ),
    );
  }
}

const String privacyPolicyText = '''
プライバシーポリシー

1. 収集する情報
当アプリケーションは、アニメリクエストフォームの提出に際し、以下の情報を収集します：
- メールアドレス
- アニメに関する情報（アニメ名、シーン、聖地の場所）
- 位置情報（任意）
- アップロードされた画像

2. 情報の使用目的
収集した情報は以下の目的で使用されます：
- アニメリクエストの処理と管理
- サービスの改善と新機能の開発
- ユーザーサポートの提供

3. 情報の共有
収集した個人情報は、聖地が掲載される場合にはユーザ名や画像が公開されます。
それ以外の個人情報については法律で定められた場合を除き、第三者と共有されることはありません。

4. データの保護
当アプリケーションは、収集した情報を保護するために適切なセキュリティ対策を講じています。

5. ユーザーの権利
ユーザーは自身の個人情報へのアクセス、訂正、削除を要求する権利を有しています。

6. プライバシーポリシーの変更
本プライバシーポリシーは変更される可能性があります。変更がある場合は、アプリケーション内で通知します。

7. お問い合わせ
プライバシーに関するご質問やお問い合わせは、japananimemaps@jam-info.comまでご連絡ください。

最終更新日：2024年11月7日
''';
