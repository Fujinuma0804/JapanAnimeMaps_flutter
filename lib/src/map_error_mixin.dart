import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_error_handler.dart';

/// Mixin that provides error handling capabilities for map widgets
mixin MapErrorHandlingMixin<T extends StatefulWidget> on State<T> {
  /// Handle location-related operations with error handling
  Future<Position?> getCurrentLocationWithErrorHandling({
    Duration timeout = const Duration(seconds: 30),
    bool showErrorDialog = true,
    bool showErrorSnackbar = false,
  }) async {
    try {
      return await MapErrorHandler.executeWithTimeout(
        () async {
          final serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            throw LocationServiceDisabledException();
          }

          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied) {
              throw PermissionDeniedException('Location permission denied');
            }
          }

          if (permission == LocationPermission.deniedForever) {
            throw Exception('Location permission permanently denied');
          }

          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
        },
        timeout: timeout,
        context: {'operation': 'location'},
      );
    } catch (error) {
      if (error is MapError) {
        _handleMapError(error, showErrorDialog, showErrorSnackbar);
        return null;
      }
      // Fallback for unexpected errors
      final mapError = MapErrorHandler.handleError(error,
          context: {'operation': 'location'});
      _handleMapError(mapError, showErrorDialog, showErrorSnackbar);
      return null;
    }
  }

  /// Handle Firestore operations with error handling
  Future<QuerySnapshot?> loadMarkersWithErrorHandling({
    Duration timeout = const Duration(seconds: 30),
    bool showErrorDialog = false,
    bool showErrorSnackbar = true,
    String? collectionName,
  }) async {
    try {
      return await MapErrorHandler.executeWithRetry(
        () async {
          final collection = FirebaseFirestore.instance
              .collection(collectionName ?? 'locations');
          return await collection.get();
        },
        timeout: timeout,
        context: {
          'operation': 'firestore',
          'collection': collectionName ?? 'locations'
        },
      );
    } catch (error) {
      if (error is MapError) {
        _handleMapError(error, showErrorDialog, showErrorSnackbar);
        return null;
      }
      // Fallback for unexpected errors
      final mapError = MapErrorHandler.handleError(error,
          context: {'operation': 'firestore'});
      _handleMapError(mapError, showErrorDialog, showErrorSnackbar);
      return null;
    }
  }

  /// Handle marker creation with error handling
  Future<Marker?> createMarkerWithErrorHandling({
    required LatLng position,
    required String markerId,
    String? imageUrl,
    String? title,
    String? snippet,
    Duration timeout = const Duration(seconds: 15),
    bool showErrorDialog = false,
    bool showErrorSnackbar = true,
  }) async {
    try {
      return await MapErrorHandler.executeWithTimeout(
        () async {
          BitmapDescriptor icon = BitmapDescriptor.defaultMarker;

          if (imageUrl != null && imageUrl.isNotEmpty) {
            try {
              icon = await _createCustomMarkerIcon(imageUrl);
            } catch (e) {
              // If custom icon fails, use default marker
              print('Failed to create custom marker icon: $e');
            }
          }

          return Marker(
            markerId: MarkerId(markerId),
            position: position,
            icon: icon,
            infoWindow: InfoWindow(
              title: title,
              snippet: snippet,
            ),
          );
        },
        timeout: timeout,
        context: {'operation': 'marker_creation', 'markerId': markerId},
      );
    } catch (error) {
      if (error is MapError) {
        _handleMapError(error, showErrorDialog, showErrorSnackbar);
        return null;
      }
      // Fallback for unexpected errors
      final mapError = MapErrorHandler.handleError(error,
          context: {'operation': 'marker_creation'});
      _handleMapError(mapError, showErrorDialog, showErrorSnackbar);
      return null;
    }
  }

  /// Handle check-in operations with error handling
  Future<bool> performCheckInWithErrorHandling({
    required String locationId,
    required String title,
    Duration timeout = const Duration(seconds: 30),
    bool showErrorDialog = true,
    bool showErrorSnackbar = false,
  }) async {
    try {
      return await MapErrorHandler.executeWithRetry(
        () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'User not authenticated',
            );
          }

          final checkInData = {
            'locationId': locationId,
            'title': title,
            'userId': user.uid,
            'timestamp': FieldValue.serverTimestamp(),
            'userEmail': user.email,
          };

          await FirebaseFirestore.instance
              .collection('checkins')
              .add(checkInData);

          return true;
        },
        timeout: timeout,
        context: {'operation': 'checkin', 'locationId': locationId},
      );
    } catch (error) {
      if (error is MapError) {
        _handleMapError(error, showErrorDialog, showErrorSnackbar);
        return false;
      }
      // Fallback for unexpected errors
      final mapError =
          MapErrorHandler.handleError(error, context: {'operation': 'checkin'});
      _handleMapError(mapError, showErrorDialog, showErrorSnackbar);
      return false;
    }
  }

  /// Handle search operations with error handling
  Future<List<DocumentSnapshot>> performSearchWithErrorHandling({
    required String query,
    Duration timeout = const Duration(seconds: 20),
    bool showErrorDialog = false,
    bool showErrorSnackbar = true,
  }) async {
    try {
      return await MapErrorHandler.executeWithTimeout(
        () async {
          final results = <DocumentSnapshot>[];

          // Search in title field
          final titleQuery = await FirebaseFirestore.instance
              .collection('locations')
              .where('title', isGreaterThanOrEqualTo: query)
              .where('title', isLessThan: query + 'z')
              .limit(10)
              .get();

          results.addAll(titleQuery.docs);

          // Search in animeName field if no results
          if (results.isEmpty) {
            final animeQuery = await FirebaseFirestore.instance
                .collection('locations')
                .where('animeName', isGreaterThanOrEqualTo: query)
                .where('animeName', isLessThan: query + 'z')
                .limit(10)
                .get();

            results.addAll(animeQuery.docs);
          }

          return results;
        },
        timeout: timeout,
        context: {'operation': 'search', 'query': query},
      );
    } catch (error) {
      if (error is MapError) {
        _handleMapError(error, showErrorDialog, showErrorSnackbar);
        return [];
      }
      // Fallback for unexpected errors
      final mapError =
          MapErrorHandler.handleError(error, context: {'operation': 'search'});
      _handleMapError(mapError, showErrorDialog, showErrorSnackbar);
      return [];
    }
  }

  /// Handle favorite toggle operations with error handling
  Future<bool> toggleFavoriteWithErrorHandling({
    required String locationId,
    Duration timeout = const Duration(seconds: 15),
    bool showErrorDialog = false,
    bool showErrorSnackbar = true,
  }) async {
    try {
      return await MapErrorHandler.executeWithRetry(
        () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'User not authenticated',
            );
          }

          final favoriteRef = FirebaseFirestore.instance
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
            await FirebaseFirestore.instance.collection('favorites').add({
              'userId': user.uid,
              'locationId': locationId,
              'timestamp': FieldValue.serverTimestamp(),
            });
            return true;
          }
        },
        timeout: timeout,
        context: {'operation': 'favorite', 'locationId': locationId},
      );
    } catch (error) {
      if (error is MapError) {
        _handleMapError(error, showErrorDialog, showErrorSnackbar);
        return false;
      }
      // Fallback for unexpected errors
      final mapError = MapErrorHandler.handleError(error,
          context: {'operation': 'favorite'});
      _handleMapError(mapError, showErrorDialog, showErrorSnackbar);
      return false;
    }
  }

  /// Handle route calculation with error handling
  Future<Map<String, dynamic>?> calculateRouteWithErrorHandling({
    required LatLng origin,
    required LatLng destination,
    String travelMode = 'DRIVE',
    Duration timeout = const Duration(seconds: 30),
    bool showErrorDialog = false,
    bool showErrorSnackbar = true,
  }) async {
    try {
      return await MapErrorHandler.executeWithTimeout(
        () async {
          // This is a simplified route calculation
          // In a real implementation, you would use Google Directions API
          final distance = Geolocator.distanceBetween(
            origin.latitude,
            origin.longitude,
            destination.latitude,
            destination.longitude,
          );

          return {
            'distance': distance,
            'duration':
                '${(distance / 1000 / 50 * 60).round()}分', // Rough estimate
            'polylines': <Polyline>{},
          };
        },
        timeout: timeout,
        context: {'operation': 'route', 'travelMode': travelMode},
      );
    } catch (error) {
      if (error is MapError) {
        _handleMapError(error, showErrorDialog, showErrorSnackbar);
        return null;
      }
      // Fallback for unexpected errors
      final mapError =
          MapErrorHandler.handleError(error, context: {'operation': 'route'});
      _handleMapError(mapError, showErrorDialog, showErrorSnackbar);
      return null;
    }
  }

  /// Generic error handling method
  void handleGenericError(
    dynamic error, {
    bool showErrorDialog = false,
    bool showErrorSnackbar = true,
    Map<String, dynamic>? context,
  }) {
    final mapError = MapErrorHandler.handleError(error, context: context);
    _handleMapError(mapError, showErrorDialog, showErrorSnackbar);
  }

  // Private helper methods

  void _handleMapError(
    MapError error,
    bool showErrorDialog,
    bool showErrorSnackbar,
  ) {
    // Log the error for debugging
    MapErrorHandler.logError(error);

    // Show appropriate UI feedback
    if (showErrorDialog && mounted) {
      MapErrorHandler.showErrorDialog(context, error);
    } else if (showErrorSnackbar && mounted) {
      MapErrorHandler.showErrorSnackbar(context, error);
    }

    // Handle specific error types
    _handleSpecificError(error);
  }

  void _handleSpecificError(MapError error) {
    switch (error.type) {
      case MapErrorType.locationPermission:
      case MapErrorType.locationService:
        // Could trigger location permission request or settings navigation
        break;
      case MapErrorType.networkConnection:
        // Could trigger network status check or retry mechanism
        break;
      case MapErrorType.firebaseAuth:
        // Could trigger re-authentication flow
        break;
      default:
        // Default handling
        break;
    }
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon(String imageUrl) async {
    // This is a simplified implementation
    // In a real app, you would download and process the image
    return BitmapDescriptor.defaultMarker;
  }
}
