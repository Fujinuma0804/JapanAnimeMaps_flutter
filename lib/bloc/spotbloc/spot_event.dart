// spot_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
