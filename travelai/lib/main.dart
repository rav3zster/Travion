import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'track_page.dart';
import 'route_alert_page.dart';
import 'map_view_page.dart';
import 'trip_history_page.dart';
import 'settings_page.dart';
import 'bus_stops_page.dart';
import 'intelligent_route_page.dart';
import 'test_stop_detection.dart';
import 'pages/detected_stops_page.dart';
import 'live_stop_detection_page.dart'; // NEW
import 'package:mappls_gl/mappls_gl.dart';
import 'mapmyindia_config.dart';

void main() async {
  // Error handling wrapper
  WidgetsFlutterBinding.ensureInitialized();

  // Setup global error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  try {
    MapplsAccountManager.setMapSDKKey(MapmyIndiaConfig.restMapSdkKey);
    MapplsAccountManager.setRestAPIKey(MapmyIndiaConfig.restMapSdkKey);
    MapplsAccountManager.setAtlasClientId(MapmyIndiaConfig.clientId);
    MapplsAccountManager.setAtlasClientSecret(MapmyIndiaConfig.clientSecret);
  } catch (e) {
    debugPrint('Error initializing Mappls: $e');
  }

  // Lock orientation to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const WayFinderApp());
}

class WayFinderApp extends StatelessWidget {
  const WayFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WayFinder',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFF0000), // Nothing Phone red accent
          secondary: Color(0xFF1A1A1A),
          surface: Color(0xFFFFFFFF),
          background: Color(0xFFFAFAFA),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF1A1A1A),
          onBackground: Color(0xFF1A1A1A),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(0))),
          elevation: 0,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          color: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.0,
            color: Color(0xFF1A1A1A),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w300,
              letterSpacing: -1,
              color: Color(0xFF1A1A1A)),
          headlineMedium: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              letterSpacing: 0,
              color: Color(0xFF1A1A1A)),
          bodyLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF666666)),
          bodyMedium: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF999999)),
        ),
      ),
      home: const HomePage(),
      routes: {
        '/settings': (context) => const SettingsPage(),
        '/detected_stops': (context) => const DetectedStopsPage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WAYFINDER'),
        actions: [
          // Dot matrix indicator (Nothing Phone style)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: List.generate(
                3,
                (index) => Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000)
                        .withOpacity(0.3 + (index * 0.2)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero section with dot matrix background
            Stack(
              children: [
                // Dot matrix background
                Positioned.fill(
                  child: CustomPaint(
                    painter: DotMatrixPainter(),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Animated red accent bar
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 4,
                              height: 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF0000),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF0000)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              margin: const EdgeInsets.only(bottom: 24),
                            ),
                          );
                        },
                      ),
                      Text(
                        'Navigate\nSmarter.',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Precision tracking with intelligent alerts.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFFFF0000), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF0000),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'SYSTEM READY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.5,
                                color: Color(0xFFFF0000),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            // Navigation Grid
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'FEATURES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2.0,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.navigation,
                    label: 'Start Tracking',
                    description: 'Real-time location tracking',
                    isAccent: true,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const TrackPage())),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.auto_awesome,
                    label: 'AI Route Finder',
                    description: 'Intelligent route planning',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const IntelligentRoutePage())),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.route,
                    label: 'Route Alert',
                    description: 'Online navigation alerts',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RouteAlertPage())),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.map_outlined,
                    label: 'Map View',
                    description: 'Interactive map interface',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MapViewPage())),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.history,
                    label: 'Trip History',
                    description: 'View past journeys',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TripHistoryPage())),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.directions_bus_outlined,
                    label: 'Bus Stops',
                    description: 'Transit stop detection',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BusStopsPage())),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.gps_fixed,
                    label: 'Live Stop Detection',
                    description: 'Real-time GPS-based detection',
                    isAccent: true,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LiveStopDetectionPage())),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.science_outlined,
                    label: 'Stop Detection',
                    description: 'Test detection algorithms',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TestStopDetectionPage())),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    description: 'App configuration',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsPage())),
                  ),
                ],
              ),
            ),

            // Footer with dot matrix
            Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(
                    5,
                    (index) => Container(
                      width: 3,
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
    bool isAccent = false,
  }) {
    return _NavItemWidget(
      icon: icon,
      label: label,
      description: description,
      onTap: onTap,
      isAccent: isAccent,
    );
  }
}

class _NavItemWidget extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool isAccent;

  const _NavItemWidget({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  State<_NavItemWidget> createState() => _NavItemWidgetState();
}

class _NavItemWidgetState extends State<_NavItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(_isHovered ? 4 : 0, 0, 0),
          child: Material(
            color: _isHovered
                ? (widget.isAccent
                    ? const Color(0xFFFF0000).withOpacity(0.02)
                    : const Color(0xFFFAFAFA))
                : Colors.white,
            child: InkWell(
              onTap: widget.onTap,
              splashColor: widget.isAccent
                  ? const Color(0xFFFF0000).withOpacity(0.1)
                  : const Color(0xFF1A1A1A).withOpacity(0.05),
              highlightColor: widget.isAccent
                  ? const Color(0xFFFF0000).withOpacity(0.05)
                  : const Color(0xFF1A1A1A).withOpacity(0.02),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isHovered
                        ? (widget.isAccent
                            ? const Color(0xFFFF0000)
                            : const Color(0xFF1A1A1A))
                        : (widget.isAccent
                            ? const Color(0xFFFF0000)
                            : const Color(0xFFE0E0E0)),
                    width: widget.isAccent ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isHovered && widget.isAccent
                            ? const Color(0xFFFF0000).withOpacity(0.1)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.isAccent
                            ? const Color(0xFFFF0000)
                            : (_isHovered
                                ? const Color(0xFF1A1A1A)
                                : const Color(0xFF666666)),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: widget.isAccent
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              color: widget.isAccent
                                  ? const Color(0xFFFF0000)
                                  : const Color(0xFF1A1A1A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.description,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF999999),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isHovered ? 0 : -0.125,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.arrow_forward,
                        color: widget.isAccent
                            ? const Color(0xFFFF0000)
                            : (_isHovered
                                ? const Color(0xFF1A1A1A)
                                : const Color(0xFF999999)),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for dot matrix background (Nothing Phone style)
class DotMatrixPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A).withOpacity(0.03)
      ..style = PaintingStyle.fill;

    const dotSize = 2.0;
    const spacing = 16.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
