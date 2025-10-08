// customer_requestformbloc.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

part 'Customer_request_event.dart';
part 'Customer_requeststate.dart';

class AnimeRequestBloc extends Bloc<AnimeRequestEvent, AnimeRequestState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Camera composition state
  double _currentZoomLevel = 1.0;
  double _currentOffsetX = 0.0;
  double _currentOffsetY = 0.0;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;

  AnimeRequestBloc() : super(AnimeRequestInitial()) {
    on<CheckUserStatusEvent>(_onCheckUserStatus);
    on<PickImageEvent>(_onPickImage);
    on<UpdateFormFieldEvent>(_onUpdateFormField);
    on<UpdateTermsAgreementEvent>(_onUpdateTermsAgreement);
    on<SubmitFormEvent>(_onSubmitForm);
    on<ClearFormEvent>(_onClearForm);
    on<RemoveImageEvent>(_onRemoveImage);

    // New events for camera composition
    on<StartVideoRecordingEvent>(_onStartVideoRecording);
    on<StopVideoRecordingEvent>(_onStopVideoRecording);
    on<UpdateCameraZoomEvent>(_onUpdateCameraZoom);
    on<UpdateCameraOffsetEvent>(_onUpdateCameraOffset);
    on<CombineWithSacredSiteEvent>(_onCombineWithSacredSite);
    on<CombineVideoWithSacredSiteEvent>(_onCombineVideoWithSacredSite);
  }

  AnimeRequestFormState get currentFormState {
    return state is AnimeRequestFormState
        ? state as AnimeRequestFormState
        : _initialFormState;
  }

  AnimeRequestFormState get _initialFormState => AnimeRequestFormState(
        isAuthorizedUser: false,
        isLoading: false,
        isSubmitting: false,
        agreeToTerms: false,
        formData: {
          'animeName': '',
          'scene': '',
          'location': '',
          'latitude': '',
          'longitude': '',
          'referenceLink': '',
          'notes': '',
        },
        animeImage: null,
        userImage: null,
        formValid: false,
        imageUploadProgress: 0.0,
        // Camera composition state
        cameraZoomLevel: 1.0,
        cameraOffsetX: 0.0,
        cameraOffsetY: 0.0,
        isRecording: false,
        recordingDuration: Duration.zero,
        combinedImagePath: null,
        combinedVideoPath: null,
      );

  // Existing methods remain the same...
  Future<void> _onCheckUserStatus(
    CheckUserStatusEvent event,
    Emitter<AnimeRequestState> emit,
  ) async {
    final user = _auth.currentUser;
    emit(_initialFormState.copyWith(
      isAuthorizedUser: user != null && !user.isAnonymous,
    ));
  }

  Future<void> _onPickImage(
    PickImageEvent event,
    Emitter<AnimeRequestState> emit,
  ) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        // Validate file size
        final fileSize = await image.length();
        if (fileSize > 10 * 1024 * 1024) {
          emit(AnimeRequestError(error: '画像ファイルサイズが大きすぎます。10MB以下にしてください。'));
          return;
        }

        // Validate file type
        final fileName = image.name.toLowerCase();
        if (!fileName.endsWith('.jpg') &&
            !fileName.endsWith('.jpeg') &&
            !fileName.endsWith('.png') &&
            !fileName.endsWith('.gif')) {
          emit(AnimeRequestError(
              error: 'サポートされていない画像形式です。JPG、PNG、GIF形式を選択してください。'));
          return;
        }

        if (event.isAnimeImage) {
          emit(currentFormState.copyWith(animeImage: image));
        } else {
          emit(currentFormState.copyWith(userImage: image));
        }
        _updateFormValidation(emit);
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
      String errorMessage = '画像の選択中にエラーが発生しました。';
      if (e.toString().contains('permission')) {
        errorMessage = '画像へのアクセス権限がありません。設定から権限を許可してください。';
      } else if (e.toString().contains('cancelled')) {
        // User cancelled, don't show error
        return;
      }
      emit(AnimeRequestError(error: errorMessage));
    }
  }

  void _onRemoveImage(
    RemoveImageEvent event,
    Emitter<AnimeRequestState> emit,
  ) {
    if (event.isAnimeImage) {
      emit(currentFormState.copyWith(animeImage: null));
    } else {
      emit(currentFormState.copyWith(userImage: null));
    }
  }

  void _onUpdateFormField(
    UpdateFormFieldEvent event,
    Emitter<AnimeRequestState> emit,
  ) {
    final updatedFormData = Map<String, String>.from(currentFormState.formData);
    updatedFormData[event.fieldName] = event.value;

    final newState = currentFormState.copyWith(formData: updatedFormData);
    emit(newState);
    _updateFormValidation(emit);
  }

  void _onUpdateTermsAgreement(
    UpdateTermsAgreementEvent event,
    Emitter<AnimeRequestState> emit,
  ) {
    final newState = currentFormState.copyWith(agreeToTerms: event.agreed);
    emit(newState);
    _updateFormValidation(emit);
  }

  void _updateFormValidation(Emitter<AnimeRequestState> emit) {
    final isValid = _validateForm(currentFormState);
    if (currentFormState.formValid != isValid) {
      emit(currentFormState.copyWith(formValid: isValid));
    }
  }

  // New camera composition methods
  void _onStartVideoRecording(
    StartVideoRecordingEvent event,
    Emitter<AnimeRequestState> emit,
  ) {
    _isRecording = true;
    _recordingDuration = Duration.zero;

    emit(currentFormState.copyWith(
      isRecording: true,
      recordingDuration: Duration.zero,
    ));
  }

  void _onStopVideoRecording(
    StopVideoRecordingEvent event,
    Emitter<AnimeRequestState> emit,
  ) {
    _isRecording = false;

    emit(currentFormState.copyWith(
      isRecording: false,
      recordingDuration: _recordingDuration,
    ));
  }

  void _onUpdateCameraZoom(
    UpdateCameraZoomEvent event,
    Emitter<AnimeRequestState> emit,
  ) {
    _currentZoomLevel = event.zoomLevel;

    emit(currentFormState.copyWith(
      cameraZoomLevel: _currentZoomLevel,
    ));
  }

  void _onUpdateCameraOffset(
    UpdateCameraOffsetEvent event,
    Emitter<AnimeRequestState> emit,
  ) {
    _currentOffsetX = event.offsetX;
    _currentOffsetY = event.offsetY;

    emit(currentFormState.copyWith(
      cameraOffsetX: _currentOffsetX,
      cameraOffsetY: _currentOffsetY,
    ));
  }

  Future<void> _onCombineWithSacredSite(
    CombineWithSacredSiteEvent event,
    Emitter<AnimeRequestState> emit,
  ) async {
    emit(currentFormState.copyWith(isLoading: true));

    try {
      // Simulate image combination process
      // In a real implementation, you would use image processing libraries
      // to combine the sacred site image with the user's captured image
      await Future.delayed(Duration(seconds: 2));

      // For now, we'll just use the captured image path
      // In production, implement actual image composition
      final combinedImagePath = event.userImagePath;

      emit(currentFormState.copyWith(
        isLoading: false,
        combinedImagePath: combinedImagePath,
      ));

      // Upload the combined image
      if (combinedImagePath != null) {
        await _uploadCombinedImage(combinedImagePath, emit);
      }
    } catch (e) {
      emit(AnimeRequestError(error: '画像の合成中にエラーが発生しました: ${e.toString()}'));
    }
  }

  Future<void> _onCombineVideoWithSacredSite(
    CombineVideoWithSacredSiteEvent event,
    Emitter<AnimeRequestState> emit,
  ) async {
    emit(currentFormState.copyWith(isLoading: true));

    try {
      // Simulate video combination process
      await Future.delayed(Duration(seconds: 3));

      // For now, we'll just use the video path
      // In production, implement actual video composition with overlay
      final combinedVideoPath = event.videoPath;

      emit(currentFormState.copyWith(
        isLoading: false,
        combinedVideoPath: combinedVideoPath,
      ));

      // Upload the combined video
      if (combinedVideoPath != null) {
        await _uploadCombinedVideo(combinedVideoPath, emit);
      }
    } catch (e) {
      emit(AnimeRequestError(error: '動画の合成中にエラーが発生しました: ${e.toString()}'));
    }
  }

  Future<void> _uploadCombinedImage(
    String imagePath,
    Emitter<AnimeRequestState> emit,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('ユーザーがログインしていません');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('customer_requests/combined_images/${timestamp}.jpg');

      // Read the image file
      final file = File(imagePath);
      final uploadTask = ref.putFile(file);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((taskSnapshot) {
        final progress =
            taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
        emit(currentFormState.copyWith(imageUploadProgress: progress));
      });

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Combined image uploaded successfully: $downloadUrl');

      // Update form data with the combined image URL
      final updatedFormData =
          Map<String, String>.from(currentFormState.formData);
      updatedFormData['combinedImageUrl'] = downloadUrl;

      emit(currentFormState.copyWith(formData: updatedFormData));
    } catch (e) {
      debugPrint('Combined image upload error: $e');
      rethrow;
    }
  }

  Future<void> _uploadCombinedVideo(
    String videoPath,
    Emitter<AnimeRequestState> emit,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('ユーザーがログインしていません');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('customer_requests/combined_videos/${timestamp}.mp4');

      // Read the video file
      final file = File(videoPath);
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((taskSnapshot) {
        final progress =
            taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
        emit(currentFormState.copyWith(imageUploadProgress: progress));
      });

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Combined video uploaded successfully: $downloadUrl');

      // Update form data with the combined video URL
      final updatedFormData =
          Map<String, String>.from(currentFormState.formData);
      updatedFormData['combinedVideoUrl'] = downloadUrl;

      emit(currentFormState.copyWith(formData: updatedFormData));
    } catch (e) {
      debugPrint('Combined video upload error: $e');
      rethrow;
    }
  }

  Future<void> _onSubmitForm(
    SubmitFormEvent event,
    Emitter<AnimeRequestState> emit,
  ) async {
    if (!_validateForm(currentFormState)) {
      emit(AnimeRequestError(error: 'すべての必須項目を入力し、利用規約に同意してください。'));
      return;
    }

    emit(currentFormState.copyWith(isSubmitting: true, isLoading: true));

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('ユーザーがログインしていません');
      }

      if (user.isAnonymous) {
        throw Exception('匿名ユーザーはリクエストを送信できません。ログインしてください。');
      }

      String? animeImageUrl;
      String? userImageUrl;
      String? combinedImageUrl;
      String? combinedVideoUrl;

      // Upload anime image if provided
      if (currentFormState.animeImage != null) {
        try {
          animeImageUrl = await _uploadImageWithProgress(
            currentFormState.animeImage!,
            true,
            emit,
          );
        } catch (e) {
          throw Exception('アニメ画像のアップロードに失敗しました: ${e.toString()}');
        }
      }

      // Upload user image if provided
      if (currentFormState.userImage != null) {
        try {
          userImageUrl = await _uploadImageWithProgress(
            currentFormState.userImage!,
            false,
            emit,
          );
        } catch (e) {
          throw Exception('ユーザー画像のアップロードに失敗しました: ${e.toString()}');
        }
      }

      // Get combined media URLs from form data
      combinedImageUrl = currentFormState.formData['combinedImageUrl'];
      combinedVideoUrl = currentFormState.formData['combinedVideoUrl'];

      // Submit form data to Firestore
      await _firestore.collection('customer_animerequest').add({
        ...currentFormState.formData,
        'userEmail': user.email,
        'animeImageUrl': animeImageUrl,
        'userImageUrl': userImageUrl,
        'combinedImageUrl': combinedImageUrl,
        'combinedVideoUrl': combinedVideoUrl,
        'cameraZoomLevel': _currentZoomLevel,
        'cameraOffsetX': _currentOffsetX,
        'cameraOffsetY': _currentOffsetY,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'request',
        'userId': user.uid,
        'userDisplayName': user.displayName ?? 'Unknown User',
        'createdAt': DateTime.now().toIso8601String(),
      });

      emit(AnimeRequestSuccess(message: 'リクエストが正常に送信されました。'));
      add(ClearFormEvent());
    } catch (e) {
      debugPrint('Error submitting form: $e');
      String errorMessage = '予期せぬエラーが発生しました。';
      if (e is FirebaseException) {
        errorMessage = 'Firebase エラー: ${e.message}';
      } else if (e is Exception) {
        errorMessage = 'エラー: ${e.toString()}';
      }
      emit(AnimeRequestError(error: errorMessage));
    } finally {
      emit(currentFormState.copyWith(
        isSubmitting: false,
        isLoading: false,
        imageUploadProgress: 0.0,
      ));
    }
  }

  void _onClearForm(
    ClearFormEvent event,
    Emitter<AnimeRequestState> emit,
  ) {
    // Reset camera composition state
    _currentZoomLevel = 1.0;
    _currentOffsetX = 0.0;
    _currentOffsetY = 0.0;
    _isRecording = false;
    _recordingDuration = Duration.zero;

    emit(_initialFormState.copyWith(
      isAuthorizedUser: currentFormState.isAuthorizedUser,
    ));
  }

  bool _validateForm(AnimeRequestFormState state) {
    final formData = state.formData;
    return formData['animeName']!.isNotEmpty &&
        formData['scene']!.isNotEmpty &&
        formData['location']!.isNotEmpty &&
        state.agreeToTerms;
  }

  Future<String> _uploadImageWithProgress(
    XFile image,
    bool isAnimeImage,
    Emitter<AnimeRequestState> emit,
  ) async {
    try {
      // Validate file size (max 10MB)
      final fileSize = await image.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('画像ファイルサイズが大きすぎます。10MB以下にしてください。');
      }

      Uint8List imageBytes = await image.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('画像のデコードに失敗しました。サポートされている画像形式をご確認ください。');
      }

      // Resize and compress image
      img.Image resizedImage = img.copyResize(
        originalImage,
        width: 1024,
        maintainAspect: true,
      );
      List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      Uint8List uint8List = Uint8List.fromList(compressedBytes);

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imageType = isAnimeImage ? 'anime' : 'user';
      final ref =
          _storage.ref().child('customer_requests/$imageType/${timestamp}.jpg');

      final uploadTask = ref.putData(
        uint8List,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'originalName': image.name,
            'uploadedBy': _auth.currentUser?.uid ?? 'anonymous',
            'imageType': imageType,
          },
        ),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((taskSnapshot) {
        final progress =
            taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
        emit(currentFormState.copyWith(imageUploadProgress: progress));
      });

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Image upload error: $e');
      rethrow;
    }
  }

  String getFieldValue(String fieldName) {
    return currentFormState.formData[fieldName] ?? '';
  }

  bool get isFormValid {
    return _validateForm(currentFormState);
  }

  @override
  Future<void> close() {
    // Dispose of any resources if needed
    return super.close();
  }
}
