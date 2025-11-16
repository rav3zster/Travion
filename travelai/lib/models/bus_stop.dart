/// Model class representing a bus stop with location and details
class BusStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? description;
  final int sequenceNumber; // Order in the route

  BusStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
    this.sequenceNumber = 0,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'sequenceNumber': sequenceNumber,
    };
  }

  /// Create from JSON
  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      description: json['description'] as String?,
      sequenceNumber: json['sequenceNumber'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    return 'BusStop(name: $name, lat: $latitude, lng: $longitude)';
  }
}
