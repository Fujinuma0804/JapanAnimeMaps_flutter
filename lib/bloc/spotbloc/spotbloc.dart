// spot_bloc.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parts/Dataprovider/apiserivce/Spotservvice.dart';
import 'package:parts/bloc/spotbloc/spot_event.dart';
import 'package:parts/bloc/spotbloc/spot_state.dart';
import 'package:parts/Dataprovider/model/spot_model.dart';

class SpotBloc extends Bloc<SpotEvent, SpotState> {
  final SpotService _spotService = SpotService();
  List<Spot> _spots = [];
  DocumentSnapshot<Spot>? _lastDoc;
  bool _hasMore = true;

  SpotBloc() : super(SpotInitial()) {
    on<SpotFetchInitial>(_onFetchInitial);
    on<SpotFetchMore>(_onFetchMore);
    on<SpotRefresh>(_onRefresh);
  }

  Future<void> _onFetchInitial(
    SpotFetchInitial event,
    Emitter<SpotState> emit,
  ) async {
    emit(SpotLoading());

    try {
      final snapshot = await _spotService.fetchFirstSpots(limit: 50);
      _spots = snapshot.docs.map((doc) => doc.data()).toList();
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length == 50;

      emit(SpotLoaded(
        spots: List.from(_spots), // Create a new list to avoid mutation issues
        hasMore: _hasMore,
        lastDoc: _lastDoc,
      ));
    } catch (e) {
      emit(SpotError('Failed to load spots: $e'));
    }
  }

  Future<void> _onFetchMore(
    SpotFetchMore event,
    Emitter<SpotState> emit,
  ) async {
    if (_lastDoc == null || !_hasMore) return;

    try {
      final snapshot = await _spotService.fetchNextSpots(
        lastDoc: _lastDoc!,
        limit: 50,
      );

      final newSpots = snapshot.docs.map((doc) => doc.data()).toList();
      _spots.addAll(newSpots);
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastDoc;
      _hasMore = snapshot.docs.length == 50;

      emit(SpotLoaded(
        spots: List.from(_spots), // Create a new list to avoid mutation issues
        hasMore: _hasMore,
        lastDoc: _lastDoc,
      ));
    } catch (e) {
      emit(SpotError('Failed to load more spots: $e'));
    }
  }

  Future<void> _onRefresh(
    SpotRefresh event,
    Emitter<SpotState> emit,
  ) async {
    // Reset state for refresh
    _spots.clear();
    _lastDoc = null;
    _hasMore = true;

    // Fetch initial data
    await _onFetchInitial(SpotFetchInitial(), emit);
  }
}
