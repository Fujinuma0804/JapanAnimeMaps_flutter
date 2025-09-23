// // map_bloc_states.dart
// part of 'map_bloc.dart';

// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';

// @immutable
// abstract class MapState {}

// class MapInitial extends MapState {}

// class MapLoading extends MapState {}

// class MapLoaded extends MapState {
//   final LatLng? currentPosition;
//   final Set<Marker> markers;
//   final Set<Circle> circles;
//   final Set<Polyline> polylines;
//   final Marker? selectedMarker;
//   final bool canCheckIn;
//   final bool hasCheckedIn;
//   final bool isLoadingRoute;
//   final String? routeDuration;
//   final String? routeDistance;
//   final String selectedTravelMode;
//   final bool isFavorite;
//   final List<DocumentSnapshot> searchResults;
//   final bool isSearching;
//   final int searchesRemaining;
//   final bool searchLimitReached;
//   final bool isSubscriptionActive;
//   final bool isAdAvailable;
//   final bool isWatchingAd;

//   MapLoaded({
//     this.currentPosition,
//     required this.markers,
//     required this.circles,
//     required this.polylines,
//     this.selectedMarker,
//     this.canCheckIn = false,
//     this.hasCheckedIn = false,
//     this.isLoadingRoute = false,
//     this.routeDuration,
//     this.routeDistance,
//     this.selectedTravelMode = 'DRIVE',
//     this.isFavorite = false,
//     this.searchResults = const [],
//     this.isSearching = false,
//     this.searchesRemaining = 3,
//     this.searchLimitReached = false,
//     this.isSubscriptionActive = false,
//     this.isAdAvailable = false,
//     this.isWatchingAd = false,
//   });

//   MapLoaded copyWith({
//     LatLng? currentPosition,
//     Set<Marker>? markers,
//     Set<Circle>? circles,
//     Set<Polyline>? polylines,
//     Marker? selectedMarker,
//     bool? canCheckIn,
//     bool? hasCheckedIn,
//     bool? isLoadingRoute,
//     String? routeDuration,
//     String? routeDistance,
//     String? selectedTravelMode,
//     bool? isFavorite,
//     List<DocumentSnapshot>? searchResults,
//     bool? isSearching,
//     int? searchesRemaining,
//     bool? searchLimitReached,
//     bool? isSubscriptionActive,
//     bool? isAdAvailable,
//     bool? isWatchingAd,
//   }) {
//     return MapLoaded(
//       currentPosition: currentPosition ?? this.currentPosition,
//       markers: markers ?? this.markers,
//       circles: circles ?? this.circles,
//       polylines: polylines ?? this.polylines,
//       selectedMarker: selectedMarker ?? this.selectedMarker,
//       canCheckIn: canCheckIn ?? this.canCheckIn,
//       hasCheckedIn: hasCheckedIn ?? this.hasCheckedIn,
//       isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
//       routeDuration: routeDuration ?? this.routeDuration,
//       routeDistance: routeDistance ?? this.routeDistance,
//       selectedTravelMode: selectedTravelMode ?? this.selectedTravelMode,
//       isFavorite: isFavorite ?? this.isFavorite,
//       searchResults: searchResults ?? this.searchResults,
//       isSearching: isSearching ?? this.isSearching,
//       searchesRemaining: searchesRemaining ?? this.searchesRemaining,
//       searchLimitReached: searchLimitReached ?? this.searchLimitReached,
//       isSubscriptionActive: isSubscriptionActive ?? this.isSubscriptionActive,
//       isAdAvailable: isAdAvailable ?? this.isAdAvailable,
//       isWatchingAd: isWatchingAd ?? this.isWatchingAd,
//     );
//   }
// }

// class MapError extends MapState {
//   final String message;
//   MapError(this.message);
// }