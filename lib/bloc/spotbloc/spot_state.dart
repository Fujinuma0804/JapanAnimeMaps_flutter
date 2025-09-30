// States
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parts/Dataprovider/model/spot_model.dart';
import 'package:equatable/equatable.dart';

abstract class SpotState extends Equatable {
  const SpotState();

  @override
  List<Object> get props => [];
}

class SpotInitial extends SpotState {}

class SpotLoading extends SpotState {}

class SpotLoaded extends SpotState {
  final List<Spot> spots;
  final bool hasMore;
  final DocumentSnapshot<Spot>? lastDoc;

  const SpotLoaded({
    required this.spots,
    required this.hasMore,
    this.lastDoc,
  });

  @override
  List<Object> get props => [spots, hasMore, lastDoc ?? Object()];
}

class SpotError extends SpotState {
  final String message;

  const SpotError(this.message);

  @override
  List<Object> get props => [message];
}
