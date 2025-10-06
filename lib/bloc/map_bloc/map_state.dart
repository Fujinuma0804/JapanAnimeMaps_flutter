part of 'map_bloc.dart';

@immutable
abstract class MapState {
  final bool isLoadingNearbyMarkers;
  final bool isLoadingMoreMarkers;

  const MapState({
    this.isLoadingNearbyMarkers = false,
    this.isLoadingMoreMarkers = false,
  });
}

class MapInitial extends MapState {
  const MapInitial()
      : super(isLoadingNearbyMarkers: false, isLoadingMoreMarkers: false);
}

class MapLoading extends MapState {
  const MapLoading()
      : super(isLoadingNearbyMarkers: true, isLoadingMoreMarkers: false);
}

class MapLoaded extends MapState {
  final LatLng? currentPosition;
  final Set<Marker> markers;
  final Set<Circle> circles;
  final Set<Polyline> polylines;
  final Marker? selectedMarker;
  final bool hasCheckedIn;
  final bool canCheckIn;
  final bool isFavorite;
  final List<DocumentSnapshot> searchResults;
  final bool isSearching;
  final String selectedTravelMode;
  final String? routeDuration;
  final String? routeDistance;
  final bool isLoadingRoute;
  final int searchesRemaining;
  final bool searchLimitReached;
  final bool isSubscriptionActive;
  final bool isCheckingSubscription;
  final bool isWatchingAd;
  final bool isAdAvailable;
  final List<DocumentSnapshot> cachedLocations;
  final DateTime? lastCacheUpdate;
  final List<QueryDocumentSnapshot> pendingMarkers;
  final bool showConfirmation;

  const MapLoaded({
    this.currentPosition,
    this.markers = const {},
    this.circles = const {},
    this.polylines = const {},
    this.selectedMarker,
    this.hasCheckedIn = false,
    this.canCheckIn = false,
    this.isFavorite = false,
    this.searchResults = const [],
    this.isSearching = false,
    this.selectedTravelMode = 'DRIVE',
    this.routeDuration,
    this.routeDistance,
    this.isLoadingRoute = false,
    this.searchesRemaining = 3,
    this.searchLimitReached = false,
    this.isSubscriptionActive = false,
    this.isCheckingSubscription = false,
    this.isWatchingAd = false,
    this.isAdAvailable = false,
    this.cachedLocations = const [],
    this.lastCacheUpdate,
    this.pendingMarkers = const [],
    this.showConfirmation = false,
    bool isLoadingNearbyMarkers = false,
    bool isLoadingMoreMarkers = false,
  }) : super(
          isLoadingNearbyMarkers: isLoadingNearbyMarkers,
          isLoadingMoreMarkers: isLoadingMoreMarkers,
        );

  MapLoaded copyWith({
    LatLng? currentPosition,
    Set<Marker>? markers,
    Set<Circle>? circles,
    Set<Polyline>? polylines,
    Marker? selectedMarker,
    bool? hasCheckedIn,
    bool? canCheckIn,
    bool? isFavorite,
    List<DocumentSnapshot>? searchResults,
    bool? isSearching,
    String? selectedTravelMode,
    String? routeDuration,
    String? routeDistance,
    bool? isLoadingRoute,
    int? searchesRemaining,
    bool? searchLimitReached,
    bool? isSubscriptionActive,
    bool? isCheckingSubscription,
    bool? isWatchingAd,
    bool? isAdAvailable,
    List<DocumentSnapshot>? cachedLocations,
    DateTime? lastCacheUpdate,
    List<QueryDocumentSnapshot>? pendingMarkers,
    bool? showConfirmation,
    bool? isLoadingNearbyMarkers,
    bool? isLoadingMoreMarkers,
  }) {
    return MapLoaded(
      currentPosition: currentPosition ?? this.currentPosition,
      markers: markers ?? this.markers,
      circles: circles ?? this.circles,
      polylines: polylines ?? this.polylines,
      selectedMarker: selectedMarker ?? this.selectedMarker,
      hasCheckedIn: hasCheckedIn ?? this.hasCheckedIn,
      canCheckIn: canCheckIn ?? this.canCheckIn,
      isFavorite: isFavorite ?? this.isFavorite,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      selectedTravelMode: selectedTravelMode ?? this.selectedTravelMode,
      routeDuration: routeDuration ?? this.routeDuration,
      routeDistance: routeDistance ?? this.routeDistance,
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
      searchesRemaining: searchesRemaining ?? this.searchesRemaining,
      searchLimitReached: searchLimitReached ?? this.searchLimitReached,
      isSubscriptionActive: isSubscriptionActive ?? this.isSubscriptionActive,
      isCheckingSubscription:
          isCheckingSubscription ?? this.isCheckingSubscription,
      isWatchingAd: isWatchingAd ?? this.isWatchingAd,
      isAdAvailable: isAdAvailable ?? this.isAdAvailable,
      cachedLocations: cachedLocations ?? this.cachedLocations,
      lastCacheUpdate: lastCacheUpdate ?? this.lastCacheUpdate,
      pendingMarkers: pendingMarkers ?? this.pendingMarkers,
      showConfirmation: showConfirmation ?? this.showConfirmation,
      isLoadingNearbyMarkers:
          isLoadingNearbyMarkers ?? this.isLoadingNearbyMarkers,
      isLoadingMoreMarkers: isLoadingMoreMarkers ?? this.isLoadingMoreMarkers,
    );
  }
}

class MapError extends MapState {
  final String message;
  const MapError(this.message)
      : super(isLoadingNearbyMarkers: false, isLoadingMoreMarkers: false);
}
