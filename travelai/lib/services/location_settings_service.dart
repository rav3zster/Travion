import 'package:shared_preferences/shared_preferences.dart';

class LocationSettings {
  final double latitude;
  final double longitude;
  final String locationName;
  final double zoom;

  LocationSettings({
    required this.latitude,
    required this.longitude,
    required this.locationName,
    this.zoom = 12.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'zoom': zoom,
    };
  }

  factory LocationSettings.fromJson(Map<String, dynamic> json) {
    return LocationSettings(
      latitude: json['latitude'] ?? 12.9141,
      longitude: json['longitude'] ?? 74.8560,
      locationName: json['locationName'] ?? 'Mangalore',
      zoom: json['zoom'] ?? 12.0,
    );
  }

  // Default locations
  static LocationSettings get mangalore => LocationSettings(
        latitude: 12.9141,
        longitude: 74.8560,
        locationName: 'Mangalore',
        zoom: 12.0,
      );

  static LocationSettings get delhi => LocationSettings(
        latitude: 28.6139,
        longitude: 77.2090,
        locationName: 'Delhi',
        zoom: 12.0,
      );

  static LocationSettings get mumbai => LocationSettings(
        latitude: 19.0760,
        longitude: 72.8777,
        locationName: 'Mumbai',
        zoom: 12.0,
      );

  static LocationSettings get bangalore => LocationSettings(
        latitude: 12.9716,
        longitude: 77.5946,
        locationName: 'Bangalore',
        zoom: 12.0,
      );

  static LocationSettings get currentLocation => LocationSettings(
        latitude: 0.0,
        longitude: 0.0,
        locationName: 'Use Current Location',
        zoom: 15.0,
      );
}

class LocationSettingsService {
  static const String _keyDefaultLocation = 'default_location';
  static const String _keyMapViewLocation = 'map_view_location';
  static const String _keyTrackPageLocation = 'track_page_location';
  static const String _keyUseCurrentLocation = 'use_current_location';

  // Save default location for all features
  static Future<void> saveDefaultLocation(LocationSettings location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultLocation, _encodeLocation(location));
  }

  // Get default location
  static Future<LocationSettings> getDefaultLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final locationString = prefs.getString(_keyDefaultLocation);
    if (locationString != null) {
      return _decodeLocation(locationString);
    }
    return LocationSettings.mangalore; // Default to Mangalore
  }

  // Save map view specific location
  static Future<void> saveMapViewLocation(LocationSettings location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMapViewLocation, _encodeLocation(location));
  }

  // Get map view location (falls back to default)
  static Future<LocationSettings> getMapViewLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final locationString = prefs.getString(_keyMapViewLocation);
    if (locationString != null) {
      return _decodeLocation(locationString);
    }
    return await getDefaultLocation();
  }

  // Save track page specific location
  static Future<void> saveTrackPageLocation(LocationSettings location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTrackPageLocation, _encodeLocation(location));
  }

  // Get track page location (falls back to default)
  static Future<LocationSettings> getTrackPageLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final locationString = prefs.getString(_keyTrackPageLocation);
    if (locationString != null) {
      return _decodeLocation(locationString);
    }
    return await getDefaultLocation();
  }

  // Toggle use current location preference
  static Future<void> setUseCurrentLocation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseCurrentLocation, value);
  }

  // Get use current location preference
  static Future<bool> getUseCurrentLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseCurrentLocation) ?? true; // Default to true
  }

  // Helper methods
  static String _encodeLocation(LocationSettings location) {
    final json = location.toJson();
    return '${json['latitude']},${json['longitude']},${json['locationName']},${json['zoom']}';
  }

  static LocationSettings _decodeLocation(String encoded) {
    final parts = encoded.split(',');
    return LocationSettings(
      latitude: double.parse(parts[0]),
      longitude: double.parse(parts[1]),
      locationName: parts[2],
      zoom: double.parse(parts[3]),
    );
  }

  // Get all preset locations
  static List<LocationSettings> getPresetLocations() {
    return [
      LocationSettings.currentLocation,
      LocationSettings.mangalore,
      LocationSettings.bangalore,
      LocationSettings.delhi,
      LocationSettings.mumbai,
    ];
  }
}
