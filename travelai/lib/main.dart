import 'package:flutter/material.dart';
import 'track_page.dart';
import 'route_alert_page.dart';
import 'map_view_page.dart';
import 'trip_history_page.dart';
import 'settings_page.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'mapmyindia_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapplsAccountManager.setMapSDKKey(MapmyIndiaConfig.restMapSdkKey);
  MapplsAccountManager.setRestAPIKey(MapmyIndiaConfig.restMapSdkKey);
  MapplsAccountManager.setAtlasClientId(MapmyIndiaConfig.clientId);
  MapplsAccountManager.setAtlasClientSecret(MapmyIndiaConfig.clientSecret);
  runApp(const WayFinderApp());
}

class WayFinderApp extends StatelessWidget {
  const WayFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WayFinder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        fontFamily: 'Roboto',
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18))),
          elevation: 6,
          margin: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF283593),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF283593)),
          headlineMedium: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF283593)),
          bodyLarge: TextStyle(fontSize: 18, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WayFinder'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe3f2fd), Color(0xFFbbdefb), Color(0xFFc5cae9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 32, horizontal: 24),
                    child: Column(
                      children: [
                        const Icon(Icons.location_on,
                            size: 72, color: Color(0xFF283593)),
                        const SizedBox(height: 18),
                        Text('Welcome to WayFinder!',
                            style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(height: 10),
                        Text(
                          'Find your way easily! Enter your destination, track your live location, and get notified as you approach your goal. See distance, estimated arrival time, and more.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.directions_run),
                      label: const Text('Start Tracking',
                          style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF283593),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const TrackPage()),
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.alt_route),
                      label: const Text('Route Alert (Online)',
                          style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3949ab),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RouteAlertPage()),
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('Map View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976d2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const MapViewPage()),
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.history),
                      label: const Text('Trip History'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897b),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const TripHistoryPage()),
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.settings),
                      label: const Text('Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6d4c41),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsPage()),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
