// map_event.dart
part of 'map_bloc.dart';

@immutable
abstract class MapEvent {}

class MapInitialized extends MapEvent {}

class LocationPermissionRequested extends MapEvent {}

class CurrentLocationRequested extends MapEvent {}

class MapCreated extends MapEvent {
  final GoogleMapController controller;
  MapCreated(this.controller);
}

class MarkersLoadRequested extends MapEvent {
  final LatLngBounds? visibleRegion;
  final LatLng? center;
  final double? radius;
  final bool isInitialLoad;
  MarkersLoadRequested({
    this.visibleRegion,
    this.center,
    this.radius,
    this.isInitialLoad = false,
  });
}

class MarkersBatchLoadRequested extends MapEvent {
  final int batchSize;
  MarkersBatchLoadRequested({this.batchSize = 10});
}

class MarkersAdded extends MapEvent {
  final Set<Marker> markers;
  MarkersAdded(this.markers);
}

class MarkerSelected extends MapEvent {
  final String markerId;
  final LatLng position;
  MarkerSelected(this.markerId, this.position);
}

class CheckInRequested extends MapEvent {
  final String locationId;
  final String title;
  CheckInRequested(this.locationId, this.title);
}

class SearchPerformed extends MapEvent {
  final String query;
  SearchPerformed(this.query);
}

class SearchLimitResetRequested extends MapEvent {}

class TravelModeChanged extends MapEvent {
  final String travelMode;
  TravelModeChanged(this.travelMode);
}

class RouteCalculationRequested extends MapEvent {
  final LatLng origin;
  final LatLng destination;
  final String travelMode;
  RouteCalculationRequested(this.origin, this.destination, this.travelMode);
}

class FavoriteToggled extends MapEvent {
  final String locationId;
  FavoriteToggled(this.locationId);
}

class NearbyMarkersRequested extends MapEvent {
  final LatLng center;
  final double radius;
  NearbyMarkersRequested(this.center, this.radius);
}

class SubscriptionStatusChecked extends MapEvent {}

class AdWatchRequested extends MapEvent {}

class AdCompleted extends MapEvent {}

class VideoPlayerInitialized extends MapEvent {
  final String videoUrl;
  VideoPlayerInitialized(this.videoUrl);
}

class CachedLocationsRequested extends MapEvent {}

class LocationsCacheUpdated extends MapEvent {
  final List<DocumentSnapshot> locations;
  LocationsCacheUpdated(this.locations);
}

