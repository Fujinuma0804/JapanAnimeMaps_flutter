part of 'Userinfo_bloc.dart';

@immutable
abstract class UserEvent {}

class InitializeUser extends UserEvent {
  InitializeUser();
}

class UpdateUserLanguage extends UserEvent {
  final String language;

  UpdateUserLanguage({required this.language});
}

class UpdateWelcomeStatus extends UserEvent {
  final bool hasSeenWelcome;

  UpdateWelcomeStatus({required this.hasSeenWelcome});
}

class UpdateCorrectCount extends UserEvent {
  final String userId;

  UpdateCorrectCount({required this.userId});
}
