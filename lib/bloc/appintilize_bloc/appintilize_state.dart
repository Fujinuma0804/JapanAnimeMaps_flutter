part of 'appintilize_bloc.dart';

@immutable
abstract class AppInitializationState {}

class InitializationInitial extends AppInitializationState {}

class InitializationLoading extends AppInitializationState {
  final String currentStep;
  final int progress;

  InitializationLoading({required this.currentStep, required this.progress});
}

class InitializationSuccess extends AppInitializationState {
  final User? user;

  InitializationSuccess({required this.user});
}

class InitializationError extends AppInitializationState {
  final String error;
  final String stackTrace;

  InitializationError({required this.error, required this.stackTrace});
}
