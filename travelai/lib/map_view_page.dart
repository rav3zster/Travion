import 'package:flutter/material.dart';
import 'package:mappls_gl/mappls_gl.dart' as mappls;

class MapViewPage extends StatelessWidget {
  const MapViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map View')),
      body: mappls.MapplsMap(
        initialCameraPosition: const mappls.CameraPosition(
          target: mappls.LatLng(28.6139, 77.2090), // Default: Delhi
          zoom: 12,
        ),
      ),
    );
  }
}
