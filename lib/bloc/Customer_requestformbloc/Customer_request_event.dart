// customer_request_event.dart
part of 'Customer_requestformbloc.dart';

abstract class AnimeRequestEvent {}

class CheckUserStatusEvent extends AnimeRequestEvent {}

class PickImageEvent extends AnimeRequestEvent {
  final bool isAnimeImage;
  PickImageEvent({required this.isAnimeImage});
}

class UpdateFormFieldEvent extends AnimeRequestEvent {
  final String fieldName;
  final String value;
  UpdateFormFieldEvent({required this.fieldName, required this.value});
}

class UpdateTermsAgreementEvent extends AnimeRequestEvent {
  final bool agreed;
  UpdateTermsAgreementEvent({required this.agreed});
}

class SubmitFormEvent extends AnimeRequestEvent {}

class ClearFormEvent extends AnimeRequestEvent {}

class RemoveImageEvent extends AnimeRequestEvent {
  final bool isAnimeImage;
  RemoveImageEvent({required this.isAnimeImage});
}

// Camera composition events
class StartVideoRecordingEvent extends AnimeRequestEvent {}

class StopVideoRecordingEvent extends AnimeRequestEvent {}

class UpdateCameraZoomEvent extends AnimeRequestEvent {
  final double zoomLevel;
  UpdateCameraZoomEvent({required this.zoomLevel});
}

class UpdateCameraOffsetEvent extends AnimeRequestEvent {
  final double offsetX;
  final double offsetY;
  UpdateCameraOffsetEvent({required this.offsetX, required this.offsetY});
}

class CombineWithSacredSiteEvent extends AnimeRequestEvent {
  final String sacredSiteImageUrl;
  final String userImagePath;
  CombineWithSacredSiteEvent({
    required this.sacredSiteImageUrl,
    required this.userImagePath,
  });
}

class CombineVideoWithSacredSiteEvent extends AnimeRequestEvent {
  final String sacredSiteImageUrl;
  final String videoPath;
  CombineVideoWithSacredSiteEvent({
    required this.sacredSiteImageUrl,
    required this.videoPath,
  });
}

// NEW EVENT: For combining with sacred site video
class CombineVideoWithSacredSiteVideoEvent extends AnimeRequestEvent {
  final String userVideoPath;
  final String sacredSiteVideoUrl;
  CombineVideoWithSacredSiteVideoEvent({
    required this.userVideoPath,
    required this.sacredSiteVideoUrl,
  });
}