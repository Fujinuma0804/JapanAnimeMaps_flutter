// customer_request_state.dart
part of 'Customer_requestformbloc.dart';

abstract class AnimeRequestState {}

class AnimeRequestInitial extends AnimeRequestState {}

class AnimeRequestLoading extends AnimeRequestState {}

class AnimeRequestSuccess extends AnimeRequestState {
  final String message;
  AnimeRequestSuccess({required this.message});
}

class AnimeRequestError extends AnimeRequestState {
  final String error;
  AnimeRequestError({required this.error});
}

class AnimeRequestFormState extends AnimeRequestState {
  final bool isAuthorizedUser;
  final bool isLoading;
  final bool isSubmitting;
  final bool agreeToTerms;
  final bool formValid;
  final XFile? animeImage;
  final XFile? userImage;
  final Map<String, String> formData;
  final double imageUploadProgress;

  // Camera composition state
  final double cameraZoomLevel;
  final double cameraOffsetX;
  final double cameraOffsetY;
  final bool isRecording;
  final Duration recordingDuration;
  final String? combinedImagePath;
  final String? combinedVideoPath;

  AnimeRequestFormState({
    required this.isAuthorizedUser,
    required this.isLoading,
    required this.isSubmitting,
    required this.agreeToTerms,
    required this.formValid,
    this.animeImage,
    this.userImage,
    required this.formData,
    required this.imageUploadProgress,
    // Camera composition state
    required this.cameraZoomLevel,
    required this.cameraOffsetX,
    required this.cameraOffsetY,
    required this.isRecording,
    required this.recordingDuration,
    this.combinedImagePath,
    this.combinedVideoPath,
  });

  AnimeRequestFormState copyWith({
    bool? isAuthorizedUser,
    bool? isLoading,
    bool? isSubmitting,
    bool? agreeToTerms,
    bool? formValid,
    XFile? animeImage,
    XFile? userImage,
    Map<String, String>? formData,
    double? imageUploadProgress,
    // Camera composition state
    double? cameraZoomLevel,
    double? cameraOffsetX,
    double? cameraOffsetY,
    bool? isRecording,
    Duration? recordingDuration,
    String? combinedImagePath,
    String? combinedVideoPath,
  }) {
    return AnimeRequestFormState(
      isAuthorizedUser: isAuthorizedUser ?? this.isAuthorizedUser,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      agreeToTerms: agreeToTerms ?? this.agreeToTerms,
      formValid: formValid ?? this.formValid,
      animeImage: animeImage ?? this.animeImage,
      userImage: userImage ?? this.userImage,
      formData: formData ?? this.formData,
      imageUploadProgress: imageUploadProgress ?? this.imageUploadProgress,
      // Camera composition state
      cameraZoomLevel: cameraZoomLevel ?? this.cameraZoomLevel,
      cameraOffsetX: cameraOffsetX ?? this.cameraOffsetX,
      cameraOffsetY: cameraOffsetY ?? this.cameraOffsetY,
      isRecording: isRecording ?? this.isRecording,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      combinedImagePath: combinedImagePath ?? this.combinedImagePath,
      combinedVideoPath: combinedVideoPath ?? this.combinedVideoPath,
    );
  }
}
