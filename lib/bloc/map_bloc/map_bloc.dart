// // map_bloc.dart
// import 'dart:async';
// import 'package:bloc/bloc.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';



// class MapBloc extends Bloc<MapEvent, MapState> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final Set<Marker> _markers = {};
//   final Set<Circle> _circles = {};
//   final Set<Polyline> _polylines = {};
  
//   GoogleMapController? _mapController;
//   StreamSubscription? _favoriteSubscription;

//   MapBloc() : super(MapInitial()) {
//     on<MapInitialized>(_onMapInitialized);
//     on<MapCreated>(_onMapCreated);
//     on<CurrentLocationRequested>(_onCurrentLocationRequested);
//     on<MarkersLoadRequested>(_onMarkersLoadRequested);
//     on<MarkerSelected>(_onMarkerSelected);
//     on<CheckInRequested>(_onCheckInRequested);
//     on<SearchPerformed>(_onSearchPerformed);
//     on<TravelModeChanged>(_onTravelModeChanged);
//     on<RouteCalculationRequested>(_onRouteCalculationRequested);
//     on<FavoriteToggled>(_onFavoriteToggled);
//   }

//   @override
//   Future<void> close() {
//     _favoriteSubscription?.cancel();
//     _mapController?.dispose();
//     return super.close();
//   }

//   Future<void> _onMapInitialized(MapInitialized event, Emitter<MapState> emit) async {
//     emit(MapLoading());
//     await _initializeUserData();
//     add(CurrentLocationRequested());
//   }

//   Future<void> _onMapCreated(MapCreated event, Emitter<MapState> emit) async {
//     _mapController = event.controller;
//     add(MarkersLoadRequested());
//   }

//   Future<void> _onCurrentLocationRequested(CurrentLocationRequested event, Emitter<MapState> emit) async {
//     try {
//       final position = await _getCurrentLocation();
//       final circles = _createCurrentLocationCircle(position);
      
//       if (state is MapLoaded) {
//         emit((state as MapLoaded).copyWith(
//           currentPosition: position,
//           circles: circles,
//         ));
//       } else {
//         emit(MapLoaded(
//           currentPosition: position,
//           markers: _markers,
//           circles: circles,
//           polylines: _polylines,
//         ));
//       }
      
//       _moveToCurrentLocation(position);
//     } catch (e) {
//       emit(MapError('位置情報の取得に失敗しました'));
//     }
//   }

//   Future<void> _onMarkersLoadRequested(MarkersLoadRequested event, Emitter<MapState> emit) async {
//     if (state is! MapLoaded) return;
    
//     try {
//       final markers = await _loadMarkersFromFirestore();
//       emit((state as MapLoaded).copyWith(markers: markers));
//     } catch (e) {
//       // Handle error but don't change state drastically
//       print('Error loading markers: $e');
//     }
//   }

//   Future<void> _onMarkerSelected(MarkerSelected event, Emitter<MapState> emit) async {
//     if (state is! MapLoaded) return;
    
//     final currentState = state as MapLoaded;
//     final hasCheckedIn = await _hasCheckedIn(event.markerId);
//     final canCheckIn = await _calculateDistance(event.position);
    
//     emit(currentState.copyWith(
//       selectedMarker: _findMarkerById(event.markerId),
//       hasCheckedIn: hasCheckedIn,
//       canCheckIn: canCheckIn,
//     ));
//   }

//   Future<void> _onCheckInRequested(CheckInRequested event, Emitter<MapState> emit) async {
//     try {
//       await _checkIn(event.locationId, event.title);
//       emit((state as MapLoaded).copyWith(hasCheckedIn: true));
//     } catch (e) {
//       emit(MapError('チェックインに失敗しました'));
//     }
//   }

//   Future<void> _onSearchPerformed(SearchPerformed event, Emitter<MapState> emit) async {
//     if (state is! MapLoaded) return;
    
//     final currentState = state as MapLoaded;
    
//     if (event.query.isEmpty) {
//       emit(currentState.copyWith(
//         searchResults: [],
//         isSearching: false,
//       ));
//       return;
//     }
    
//     emit(currentState.copyWith(isSearching: true));
    
//     try {
//       final results = await _performSearch(event.query);
//       final updatedState = await _updateSearchLimit(currentState);
      
//       emit(updatedState.copyWith(
//         searchResults: results,
//         isSearching: false,
//       ));
//     } catch (e) {
//       emit(currentState.copyWith(isSearching: false));
//     }
//   }

//   Future<void> _onTravelModeChanged(TravelModeChanged event, Emitter<MapState> emit) async {
//     if (state is! MapLoaded) return;
    
//     emit((state as MapLoaded).copyWith(
//       selectedTravelMode: event.travelMode,
//       isLoadingRoute: true,
//     ));
//   }

//   Future<void> _onRouteCalculationRequested(RouteCalculationRequested event, Emitter<MapState> emit) async {
//     if (state is! MapLoaded) return;
    
//     try {
//       final routeData = await _calculateRoute(event.origin, event.destination);
//       emit((state as MapLoaded).copyWith(
//         polylines: routeData.polylines,
//         routeDuration: routeData.duration,
//         routeDistance: routeData.distance,
//         isLoadingRoute: false,
//       ));
//     } catch (e) {
//       emit((state as MapLoaded).copyWith(isLoadingRoute: false));
//     }
//   }

//   Future<void> _onFavoriteToggled(FavoriteToggled event, Emitter<MapState> emit) async {
//     if (state is! MapLoaded) return;
    
//     try {
//       final isFavorite = await _toggleFavorite(event.locationId);
//       emit((state as MapLoaded).copyWith(isFavorite: isFavorite));
//     } catch (e) {
//       // Handle error silently
//       print('Error toggling favorite: $e');
//     }
//   }

//   // Helper methods (extracted from original class)
//   Future<Position> _getCurrentLocation() async {
//     // Implementation from original _getCurrentLocation method
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       throw Exception('位置情報サービスが無効です');
//     }

//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         throw Exception('位置情報の許可が必要です');
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       throw Exception('位置情報が永久に拒否されました');
//     }

//     return await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//   }

//   Set<Circle> _createCurrentLocationCircle(LatLng position) {
//     return {
//       Circle(
//         circleId: const CircleId('current_location'),
//         center: position,
//         radius: 10,
//         fillColor: Colors.blue.withOpacity(0.3),
//         strokeColor: Colors.blue,
//         strokeWidth: 2,
//       ),
//     };
//   }

//   void _moveToCurrentLocation(LatLng position) {
//     _mapController?.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(
//           target: position,
//           zoom: 16.0,
//           bearing: 30.0,
//           tilt: 60.0,
//         ),
//       ),
//     );
//   }

//   Future<Set<Marker>> _loadMarkersFromFirestore() async {
//     // Implementation from original _loadMarkersFromFirestore method
//     // Simplified version - you'll need to adapt the marker creation logic
//     final snapshot = await _firestore.collection('locations').limit(20).get();
    
//     final markers = <Marker>{};
//     for (final doc in snapshot.docs) {
//       final marker = await _createMarkerFromDoc(doc);
//       if (marker != null) {
//         markers.add(marker);
//       }
//     }
    
//     return markers;
//   }

//   Future<Marker?> _createMarkerFromDoc(DocumentSnapshot doc) async {
//     // Marker creation logic from original _createMarkerWithImage
//     // Simplified implementation
//     final data = doc.data() as Map<String, dynamic>;
//     final position = LatLng(
//       (data['latitude'] as num).toDouble(),
//       (data['longitude'] as num).toDouble(),
//     );
    
//     return Marker(
//       markerId: MarkerId(doc.id),
//       position: position,
//       onTap: () {
//         add(MarkerSelected(doc.id, position));
//       },
//     );
//   }

//   // Add other helper methods similarly...
// }