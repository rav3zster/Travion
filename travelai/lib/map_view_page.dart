import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mappls_gl/mappls_gl.dart' as mappls;
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'services/location_settings_service.dart' as settings;

class MapViewPage extends StatefulWidget {
  const MapViewPage({super.key});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  mappls.CameraPosition? _initialPosition;
  bool _isLoading = true;
  mappls.MapplsMapController? _mapController;
  mappls.LatLng? _selectedLocation;
  bool _showCoordinatePanel = false;

  @override
  void initState() {
    super.initState();
    _loadInitialLocation();
  }

  void _onMapCreated(mappls.MapplsMapController controller) {
    _mapController = controller;
  }

  void _onMapClick(dynamic point, mappls.LatLng coordinates) {
    setState(() {
      _selectedLocation = coordinates;
      _showCoordinatePanel = true;
    });

    // Add a marker at the clicked location
    _mapController?.clearSymbols();
    _mapController?.addSymbol(
      mappls.SymbolOptions(
        geometry: coordinates,
        iconImage: 'marker-icon',
        iconSize: 1.0,
      ),
    );
  }

  void _copyCoordinates() {
    if (_selectedLocation != null) {
      final coordText =
          '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}';
      Clipboard.setData(ClipboardData(text: coordText));
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Copied: $coordText'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyLatitude() {
    if (_selectedLocation != null) {
      final lat = _selectedLocation!.latitude.toStringAsFixed(6);
      Clipboard.setData(ClipboardData(text: lat));
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied Latitude: $lat'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _copyLongitude() {
    if (_selectedLocation != null) {
      final lng = _selectedLocation!.longitude.toStringAsFixed(6);
      Clipboard.setData(ClipboardData(text: lng));
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied Longitude: $lng'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _shareCoordinates() {
    if (_selectedLocation != null) {
      final coordText =
          'Latitude: ${_selectedLocation!.latitude.toStringAsFixed(6)}\nLongitude: ${_selectedLocation!.longitude.toStringAsFixed(6)}';
      Clipboard.setData(ClipboardData(text: coordText));
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coordinates copied to clipboard (detailed format)'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _getCurrentLocationCoordinates() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLocation =
            mappls.LatLng(position.latitude, position.longitude);
        _showCoordinatePanel = true;
      });

      _mapController?.animateCamera(
        mappls.CameraUpdate.newLatLngZoom(
          mappls.LatLng(position.latitude, position.longitude),
          15,
        ),
      );

      _mapController?.clearSymbols();
      _mapController?.addSymbol(
        mappls.SymbolOptions(
          geometry: mappls.LatLng(position.latitude, position.longitude),
          iconImage: 'marker-icon',
          iconSize: 1.0,
        ),
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current location retrieved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadInitialLocation() async {
    final useCurrentLocation =
        await settings.LocationSettingsService.getUseCurrentLocation();
    final savedLocation =
        await settings.LocationSettingsService.getMapViewLocation();

    mappls.CameraPosition position;

    if (useCurrentLocation &&
        savedLocation.locationName != 'Use Current Location') {
      // Try to get current location
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            final currentPos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            ).timeout(const Duration(seconds: 5), onTimeout: () {
              throw TimeoutException('Location timeout');
            });
            position = mappls.CameraPosition(
              target: mappls.LatLng(currentPos.latitude, currentPos.longitude),
              zoom: 15,
            );
          } else {
            // Use saved location if no permission
            position = mappls.CameraPosition(
              target: mappls.LatLng(
                  savedLocation.latitude, savedLocation.longitude),
              zoom: savedLocation.zoom,
            );
          }
        } else {
          // Use saved location if location service disabled
          position = mappls.CameraPosition(
            target:
                mappls.LatLng(savedLocation.latitude, savedLocation.longitude),
            zoom: savedLocation.zoom,
          );
        }
      } catch (e) {
        // Fallback to saved location on error
        position = mappls.CameraPosition(
          target:
              mappls.LatLng(savedLocation.latitude, savedLocation.longitude),
          zoom: savedLocation.zoom,
        );
      }
    } else {
      // Use saved location
      position = mappls.CameraPosition(
        target: mappls.LatLng(savedLocation.latitude, savedLocation.longitude),
        zoom: savedLocation.zoom,
      );
    }

    setState(() {
      _initialPosition = position;
      _isLoading = false;
    });
  }

  void _zoomIn() {
    _mapController?.animateCamera(
      mappls.CameraUpdate.zoomIn(),
    );
  }

  void _zoomOut() {
    _mapController?.animateCamera(
      mappls.CameraUpdate.zoomOut(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map View'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Get Current Location Coordinates',
            onPressed: _getCurrentLocationCoordinates,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Location Settings',
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading map...'),
                ],
              ),
            )
          : Stack(
              children: [
                mappls.MapplsMap(
                  initialCameraPosition: _initialPosition!,
                  myLocationEnabled: true,
                  onMapCreated: _onMapCreated,
                  onMapClick: _onMapClick,
                ),
                // Zoom controls
                Positioned(
                  right: 16,
                  top: MediaQuery.of(context).size.height / 2 - 80,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'zoom_in',
                        mini: true,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF283593),
                        onPressed: _zoomIn,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'zoom_out',
                        mini: true,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF283593),
                        onPressed: _zoomOut,
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
                if (_showCoordinatePanel && _selectedLocation != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          // Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        color: Color(0xFF283593)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Location Coordinates',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF283593),
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _showCoordinatePanel = false;
                                      _selectedLocation = null;
                                    });
                                    _mapController?.clearSymbols();
                                  },
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 1),

                          // Coordinates Display
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Full coordinates with copy button
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Coordinates',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy,
                                            color: Color(0xFF283593)),
                                        tooltip: 'Copy Both',
                                        onPressed: _copyCoordinates,
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Individual coordinate cards
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.green[200]!),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Latitude',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.copy,
                                                      size: 18),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  onPressed: _copyLatitude,
                                                ),
                                              ],
                                            ),
                                            Text(
                                              _selectedLocation!.latitude
                                                  .toStringAsFixed(6),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.orange[200]!),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Longitude',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.copy,
                                                      size: 18),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  onPressed: _copyLongitude,
                                                ),
                                              ],
                                            ),
                                            Text(
                                              _selectedLocation!.longitude
                                                  .toStringAsFixed(6),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Action button
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.share),
                                  label: const Text('Copy Detailed Format'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF283593),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _shareCoordinates,
                                ),
                              ],
                            ),
                          ),

                          // Instruction
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.grey[100],
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: Colors.grey),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tap anywhere on the map to get coordinates',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
