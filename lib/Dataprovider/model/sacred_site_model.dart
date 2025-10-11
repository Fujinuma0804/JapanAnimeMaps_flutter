// Sacred Site Data Model
class SacredSite {
  final String id;
  final String imageUrl;
  final String locationID;
  final double latitude;
  final double longitude;
  final int point;
  final String sourceLink;
  final String sourceTitle;
  final String subMedia;
  final double? distance; // Distance from user in kilometers

  SacredSite({
    required this.id,
    required this.imageUrl,
    required this.locationID,
    required this.latitude,
    required this.longitude,
    required this.point,
    required this.sourceLink,
    required this.sourceTitle,
    required this.subMedia,
    this.distance,
  });
}
