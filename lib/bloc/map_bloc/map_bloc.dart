// map_bloc.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
part 'map_event.dart';
part 'map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  GoogleMapController? _mapController;
  StreamSubscription? _favoriteSubscription;

  MapBloc() : super(MapInitial()) {
    on<MapInitialized>(_onMapInitialized);
    on<MapCreated>(_onMapCreated);
    on<CurrentLocationRequested>(_onCurrentLocationRequested);
    on<MarkersLoadRequested>(_onMarkersLoadRequested);
    on<MarkerSelected>(_onMarkerSelected);
    on<CheckInRequested>(_onCheckInRequested);
    on<SearchPerformed>(_onSearchPerformed);
    on<TravelModeChanged>(_onTravelModeChanged);
    on<RouteCalculationRequested>(_onRouteCalculationRequested);
    on<FavoriteToggled>(_onFavoriteToggled);
  }

  @override
  Future<void> close() {
    _favoriteSubscription?.cancel();
    _mapController?.dispose();
    return super.close();
  }

  Future<void> _onMapInitialized(
      MapInitialized event, Emitter<MapState> emit) async {
    emit(MapLoading());
    await _initializeUserData();
    add(CurrentLocationRequested());
  }

  Future<void> _onMapCreated(MapCreated event, Emitter<MapState> emit) async {
    _mapController = event.controller;
    add(MarkersLoadRequested());
  }

  Future<void> _onCurrentLocationRequested(
      CurrentLocationRequested event, Emitter<MapState> emit) async {
    try {
      final position = await _getCurrentLocation();
      final latLng = LatLng(position.latitude, position.longitude);
      final circles = _createCurrentLocationCircle(latLng);

      if (state is MapLoaded) {
        emit((state as MapLoaded).copyWith(
          currentPosition: latLng,
          circles: circles,
        ));
      } else {
        emit(MapLoaded(
          currentPosition: latLng,
          markers: _markers,
          circles: circles,
          polylines: _polylines,
        ));
      }

      _moveToCurrentLocation(latLng);
    } catch (e) {
      emit(MapError('位置情報の取得に失敗しました'));
    }
  }

  Future<void> _onMarkersLoadRequested(
      MarkersLoadRequested event, Emitter<MapState> emit) async {
    if (state is! MapLoaded) return;

    try {
      final markers = await _loadMarkersFromFirestore();
      emit((state as MapLoaded).copyWith(markers: markers));
    } catch (e) {
      // Handle error but don't change state drastically
      print('Error loading markers: $e');
    }
  }

  Future<void> _onMarkerSelected(
      MarkerSelected event, Emitter<MapState> emit) async {
    if (state is! MapLoaded) return;

    final currentState = state as MapLoaded;
    final hasCheckedIn = await _hasCheckedIn(event.markerId);
    final canCheckIn = await _calculateDistance(event.position);

    emit(currentState.copyWith(
      selectedMarker: _findMarkerById(event.markerId),
      hasCheckedIn: hasCheckedIn,
      canCheckIn: canCheckIn,
    ));
  }

  Future<void> _onCheckInRequested(
      CheckInRequested event, Emitter<MapState> emit) async {
    try {
      await _checkIn(event.locationId, event.title);
      emit((state as MapLoaded).copyWith(hasCheckedIn: true));
    } catch (e) {
      emit(MapError('チェックインに失敗しました'));
    }
  }

  Future<void> _onSearchPerformed(
      SearchPerformed event, Emitter<MapState> emit) async {
    if (state is! MapLoaded) return;

    final currentState = state as MapLoaded;

    if (event.query.isEmpty) {
      emit(currentState.copyWith(
        searchResults: [],
        isSearching: false,
      ));
      return;
    }

    emit(currentState.copyWith(isSearching: true));

    try {
      final results = await _performSearch(event.query);
      final updatedState = await _updateSearchLimit(currentState);

      emit(updatedState.copyWith(
        searchResults: results,
        isSearching: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isSearching: false));
    }
  }

  Future<void> _onTravelModeChanged(
      TravelModeChanged event, Emitter<MapState> emit) async {
    if (state is! MapLoaded) return;

    emit((state as MapLoaded).copyWith(
      selectedTravelMode: event.travelMode,
      isLoadingRoute: true,
    ));
  }

  Future<void> _onRouteCalculationRequested(
      RouteCalculationRequested event, Emitter<MapState> emit) async {
    if (state is! MapLoaded) return;

    try {
      final routeData = await _calculateRoute(event.origin, event.destination);
      emit((state as MapLoaded).copyWith(
        polylines: routeData['polylines'] as Set<Polyline>,
        routeDuration: routeData['duration'] as String,
        routeDistance: routeData['distance'] as String,
        isLoadingRoute: false,
      ));
    } catch (e) {
      emit((state as MapLoaded).copyWith(isLoadingRoute: false));
    }
  }

  Future<void> _onFavoriteToggled(
      FavoriteToggled event, Emitter<MapState> emit) async {
    if (state is! MapLoaded) return;

    try {
      final isFavorite = await _toggleFavorite(event.locationId);
      emit((state as MapLoaded).copyWith(isFavorite: isFavorite));
    } catch (e) {
      // Handle error silently
      print('Error toggling favorite: $e');
    }
  }

  // Helper methods (extracted from original class)
  Future<Position> _getCurrentLocation() async {
    // Implementation from original _getCurrentLocation method
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('位置情報サービスが無効です');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('位置情報の許可が必要です');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('位置情報が永久に拒否されました');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Set<Circle> _createCurrentLocationCircle(LatLng position) {
    return {
      Circle(
        circleId: const CircleId('current_location'),
        center: position,
        radius: 10,
        fillColor: Colors.blue.withValues(alpha: 0.3),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      ),
    };
  }

  void _moveToCurrentLocation(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 16.0,
          bearing: 30.0,
          tilt: 60.0,
        ),
      ),
    );
  }

  Future<Set<Marker>> _loadMarkersFromFirestore() async {
    // Implementation from original _loadMarkersFromFirestore method
    // Simplified version - you'll need to adapt the marker creation logic
    final snapshot = await _firestore.collection('locations').limit(20).get();

    final markers = <Marker>{};
    for (final doc in snapshot.docs) {
      final marker = await _createMarkerFromDoc(doc);
      if (marker != null) {
        markers.add(marker);
      }
    }

    return markers;
  }

  Future<Marker?> _createMarkerFromDoc(DocumentSnapshot doc) async {
    // Marker creation logic from original _createMarkerWithImage
    // Simplified implementation
    final data = doc.data() as Map<String, dynamic>;
    final position = LatLng(
      (data['latitude'] as num).toDouble(),
      (data['longitude'] as num).toDouble(),
    );
    String imageUrl = data['imageUrl'] ?? '';
    const int height = 200;
    const int width = 300;
    final Uint8List markerIcon =
        await _getBytesFromUrl(imageUrl, width, height);

    // Use compute to move image processing to a separate isolate
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = Colors.white;
    // 吹き出しの描画（先端を下に移動）
    final Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(0, height + 20);
    path.lineTo((width + 40) / 2 - 10, height + 20);
    path.lineTo((width + 40) / 2, height + 40);
    path.lineTo((width + 40) / 2 + 10, height + 20);
    path.lineTo(width + 40, height + 20);
    path.lineTo(width + 40, 0);
    path.close();

    canvas.drawPath(path, paint);

    // 画像の描画
    final ui.Image image = await decodeImageFromList(markerIcon);

    const double scaleFactor = 0.95;
    const double scaledWidth = (width + 40) * scaleFactor;
    const double scaledHeight = (height + 20) * scaleFactor;
    const double offsetX = ((width + 40) - scaledWidth) / 2;
    const double offsetY = ((height + 20) - scaledHeight) / 2;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight),
      Paint(),
    );

    final img =
        await pictureRecorder.endRecording().toImage(width + 40, height + 60);
    final imgData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (imgData == null) return null;

    return Marker(
      markerId: MarkerId(doc.id),
      position: position,
      icon: BitmapDescriptor.fromBytes(imgData.buffer.asUint8List()),
      onTap: () {
        add(MarkerSelected(doc.id, position));
      },
    );
  }

  // Helper methods implementation
  Future<void> _initializeUserData() async {
    // Initialize user data if needed
    // This could include checking subscription status, user preferences, etc.
  }

  Future<bool> _hasCheckedIn(String markerId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final checkInQuery = await _firestore
          .collection('checkins')
          .where('userId', isEqualTo: user.uid)
          .where('locationId', isEqualTo: markerId)
          .limit(1)
          .get();

      return checkInQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking check-in status: $e');
      return false;
    }
  }

  Future<bool> _calculateDistance(LatLng position) async {
    try {
      if (state is! MapLoaded) return false;

      final currentState = state as MapLoaded;
      if (currentState.currentPosition == null) return false;

      final distance = Geolocator.distanceBetween(
        currentState.currentPosition!.latitude,
        currentState.currentPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Allow check-in within 100 meters
      return distance <= 100;
    } catch (e) {
      print('Error calculating distance: $e');
      return false;
    }
  }

  Future<Uint8List> _getBytesFromUrl(String url, int width, int height) async {
    try {
      final http.Response response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load image, status code: ${response.statusCode}');
      }

      final ui.Codec codec = await ui.instantiateImageCodec(
        response.bodyBytes,
        targetWidth: width,
        targetHeight: height,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ByteData? byteData =
          await fi.image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      print('Error loading image from URL: $e');
      // Return a fallback/placeholder image or rethrow
      throw e;
    }
  }

  Marker? _findMarkerById(String markerId) {
    try {
      return _markers.firstWhere(
        (marker) => marker.markerId.value == markerId,
        orElse: () => throw StateError('Marker not found'),
      );
    } catch (e) {
      print('Error finding marker: $e');
      return null;
    }
  }

  Future<void> _checkIn(String locationId, String title) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final checkInData = {
        'locationId': locationId,
        'title': title,
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'userEmail': user.email,
      };

      await _firestore.collection('checkins').add(checkInData);
    } catch (e) {
      print('Error during check-in: $e');
      rethrow;
    }
  }

  Future<List<DocumentSnapshot>> _performSearch(String query) async {
    try {
      final results = <DocumentSnapshot>[];

      // Search in title field
      final titleQuery = await _firestore
          .collection('locations')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: query + 'z')
          .limit(10)
          .get();

      results.addAll(titleQuery.docs);

      // Search in animeName field if no results
      if (results.isEmpty) {
        final animeQuery = await _firestore
            .collection('locations')
            .where('animeName', isGreaterThanOrEqualTo: query)
            .where('animeName', isLessThan: query + 'z')
            .limit(10)
            .get();

        results.addAll(animeQuery.docs);
      }

      return results;
    } catch (e) {
      print('Error performing search: $e');
      return [];
    }
  }

  Future<MapLoaded> _updateSearchLimit(MapLoaded currentState) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return currentState;

      // Get current search count
      final searchCountDoc =
          await _firestore.collection('userSearchLimits').doc(user.uid).get();

      int currentCount = 0;
      if (searchCountDoc.exists) {
        currentCount = (searchCountDoc.data()?['count'] as int?) ?? 0;
      }

      // Increment count
      currentCount++;

      // Update search count
      await _firestore.collection('userSearchLimits').doc(user.uid).set({
        'count': currentCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Check if limit reached (assuming 3 searches per day for free users)
      final isLimitReached = currentCount >= 3;
      final remaining = isLimitReached ? 0 : 3 - currentCount;

      return currentState.copyWith(
        searchesRemaining: remaining,
        searchLimitReached: isLimitReached,
      );
    } catch (e) {
      print('Error updating search limit: $e');
      return currentState;
    }
  }

  Future<Map<String, dynamic>> _calculateRoute(
      LatLng origin, LatLng destination) async {
    try {
      // This is a simplified route calculation
      // In a real implementation, you would use Google Directions API
      final distance = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );

      return {
        'distance': '${(distance / 1000).toStringAsFixed(1)} km',
        'duration': '${(distance / 1000 / 50 * 60).round()}分', // Rough estimate
        'polylines': <Polyline>{},
      };
    } catch (e) {
      print('Error calculating route: $e');
      rethrow;
    }
  }

  Future<bool> _toggleFavorite(String locationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final favoriteRef = _firestore
          .collection('favorites')
          .where('userId', isEqualTo: user.uid)
          .where('locationId', isEqualTo: locationId)
          .limit(1);

      final existingFavorites = await favoriteRef.get();

      if (existingFavorites.docs.isNotEmpty) {
        // Remove from favorites
        await existingFavorites.docs.first.reference.delete();
        return false;
      } else {
        // Add to favorites
        await _firestore.collection('favorites').add({
          'userId': user.uid,
          'locationId': locationId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        return true;
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      rethrow;
    }
  }
}
