class LocationVenueItem {
  final String id;
  final String name;
  final String address;
  final double rating;
  final int reviewsCount;
  final String distance;
  final String imageAsset;

  const LocationVenueItem({
    required this.id,
    required this.name,
    required this.address,
    required this.rating,
    required this.reviewsCount,
    required this.distance,
    required this.imageAsset,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationVenueItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
