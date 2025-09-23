// // map_bloc_events.dart
// part of 'map_bloc.dart';

// import 'package:flutter/material.dart' show immutable;
// import 'package:google_maps_flutter/google_maps_flutter.dart';

// @immutable
// abstract class MapEvent {}

// class MapInitialized extends MapEvent {}

// class LocationPermissionRequested extends MapEvent {}

// class CurrentLocationRequested extends MapEvent {}

// class MapCreated extends MapEvent {
//   final GoogleMapController controller;
//   MapCreated(this.controller);
// }

// class MarkersLoadRequested extends MapEvent {
//   final LatLngBounds? visibleRegion;
//   MarkersLoadRequested({this.visibleRegion});
// }

// class MarkerSelected extends MapEvent {
//   final String markerId;
//   final LatLng position;
//   MarkerSelected(this.markerId, this.position);
// }

// class CheckInRequested extends MapEvent {
//   final String locationId;
//   final String title;
//   CheckInRequested(this.locationId, this.title);
// }

// class SearchPerformed extends MapEvent {
//   final String query;
//   SearchPerformed(this.query);
// }

// class SearchLimitResetRequested extends MapEvent {}

// class TravelModeChanged extends MapEvent {
//   final String travelMode;
//   TravelModeChanged(this.travelMode);
// }

// class RouteCalculationRequested extends MapEvent {
//   final LatLng origin;
//   final LatLng destination;
//   RouteCalculationRequested(this.origin, this.destination);
// }

// class FavoriteToggled extends MapEvent {
//   final String locationId;
//   FavoriteToggled(this.locationId);
// }