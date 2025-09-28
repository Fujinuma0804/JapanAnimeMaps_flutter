part of 'Userinfo_bloc.dart';

@immutable
abstract class UserState {}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserInitialized extends UserState {
  final User user;

  UserInitialized({required this.user});
}

class UserDataLoaded extends UserState {
  final User user;
  final String language;
  final bool hasSeenWelcome;

  UserDataLoaded({
    required this.user,
    required this.language,
    required this.hasSeenWelcome,
  });

  UserDataLoaded copyWith({
    User? user,
    String? language,
    bool? hasSeenWelcome,
  }) {
    return UserDataLoaded(
      user: user ?? this.user,
      language: language ?? this.language,
      hasSeenWelcome: hasSeenWelcome ?? this.hasSeenWelcome,
    );
  }
}

class UserError extends UserState {
  final String message;

  UserError(this.message);
}
