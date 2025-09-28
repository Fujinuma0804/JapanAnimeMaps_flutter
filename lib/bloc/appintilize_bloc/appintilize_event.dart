part of 'appintilize_bloc.dart';

@immutable
abstract class AppInitializationEvent {}

class StartInitialization extends AppInitializationEvent {
  StartInitialization();
}

class UpdateInitializationProgress extends AppInitializationEvent {
  final String step;
  final int progress;

  UpdateInitializationProgress({required this.step, required this.progress});
}
