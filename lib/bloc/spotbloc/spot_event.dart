// spot_bloc.dart
import 'package:equatable/equatable.dart';

// Events
abstract class SpotEvent extends Equatable {
  const SpotEvent();

  @override
  List<Object> get props => [];
}

class SpotFetchInitial extends SpotEvent {}

class SpotFetchMore extends SpotEvent {}

class SpotRefresh extends SpotEvent {}
