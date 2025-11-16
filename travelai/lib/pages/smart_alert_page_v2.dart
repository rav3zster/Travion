import 'package:flutter/material.dart';
import '../services/route_learning_service.dart';

/// Intelligent Route-Based Alert System (Route Learning Version)
/// Suggests stops based on LEARNED routes from actual GPS tracking
class SmartAlertPage extends StatefulWidget {
  const SmartAlertPage({Key? key}) : super(key: key);

  @override
  State<SmartAlertPage> createState() => _SmartAlertPageState();
}

class _SmartAlertPageState extends State<SmartAlertPage> {
  final RouteLearningService _routeService = RouteLearningService();

  // User input
  String? selectedOrigin;
  String? selectedDestination;

  // Available routes
  List<Map<String, dynamic>> learnedRoutes = [];
  Map<String, dynamic>? selectedRoute;

  // Stop suggestions
  List<Map<String, dynamic>> suggestedStops = [];
  Set<String> selectedAlerts = {};

  // UI state
  bool isLoading = false;
  bool showSuggestions = false;
  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    _loadLearnedRoutes();
  }

  Future<void> _loadLearnedRoutes() async {
    setState(() => isLoading = true);

    try {
      final routes = await _routeService.getLearnedRoutes();
      setState(() {
        learnedRoutes = routes;
        isLoading = false;
      });

      if (routes.isEmpty) {
        _showNoRoutesDialog();
      }
    } catch (e) {
      setState(() => isLoading = false);
      print('Error loading routes: $e');
    }
  }

  void _showNoRoutesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📚 No Routes Learned Yet'),
        content: const Text(
          'You need to record at least one bus journey first!\n\n'
          'Steps:\n'
          '1. Go to Track Page\n'
          '2. Start tracking your journey\n'
          '3. System will learn the route automatically\n'
          '4. Come back here to set up alerts\n\n'
          'The more you travel, the smarter it gets!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateSuggestions() async {
    if (selectedOrigin == null || selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select both origin and destination')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Find learned route
      final route = await _routeService.findRoute(
        origin: selectedOrigin!,
        destination: selectedDestination!,
      );

      if (route == null) {
        _showNoRouteFoundDialog();
        setState(() => isLoading = false);
        return;
      }

      // Get stops from learned route
      final stops = route['stops'] as List<Map<String, dynamic>>?;

      setState(() {
        selectedRoute = route;
        suggestedStops = stops ?? [];
        showSuggestions = true;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('Error finding route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showNoRouteFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🤔 Route Not Found'),
        content: Text(
          'No learned route from $selectedOrigin to $selectedDestination.\n\n'
          'This could mean:\n'
          '• You haven\'t traveled this route yet\n'
          '• The route was saved with different stop names\n\n'
          'Would you like to record this route now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startRouteRecording();
            },
            child: const Text('Record Route'),
          ),
        ],
      ),
    );
  }

  Future<void> _startRouteRecording() async {
    try {
      final journeyId = await _routeService.startJourneyRecording(
        routeName: '$selectedOrigin to $selectedDestination',
      );

      setState(() => isRecording = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎯 Recording route: $journeyId'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Stop',
              onPressed: _stopRouteRecording,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRouteRecording() async {
    try {
      await _routeService.endJourneyRecording(
        endLocation: selectedDestination,
      );

      setState(() => isRecording = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Route recorded! Analyzing...'),
            duration: Duration(seconds: 2),
          ),
        );

        // Reload routes
        await _loadLearnedRoutes();
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  void _activateAlerts() {
    if (selectedAlerts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one stop')),
      );
      return;
    }

    // TODO: Save selected alerts to database for monitoring
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Alerts Activated'),
        content: Text(
          'You will be notified when approaching:\n\n'
          '${selectedAlerts.map((s) => '• $s').join('\n')}\n\n'
          'Make sure GPS tracking is enabled!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Alerts'),
        actions: [
          if (isRecording)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              tooltip: 'Stop Recording',
              onPressed: _stopRouteRecording,
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Journey History',
            onPressed: _showJourneyHistory,
          ),
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'View Routes',
            onPressed: _showLearnedRoutes,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isRecording) _buildRecordingIndicator(),
                  _buildInstructionCard(),
                  const SizedBox(height: 16),
                  _buildRouteSelector(),
                  const SizedBox(height: 16),
                  if (showSuggestions) ...[
                    _buildRouteInfo(),
                    const SizedBox(height: 16),
                    _buildSuggestedStops(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.fiber_manual_record, color: Colors.red),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '🎯 Recording route... System is learning!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: _stopRouteRecording,
              child: const Text('STOP'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'How It Works',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '1. System learns actual bus routes from GPS tracking\n'
              '2. Select your origin and destination\n'
              '3. Get smart suggestions from REAL route data\n'
              '4. Choose which stops to get notified about\n\n'
              '💡 Example: Mangalore → Karkala shows:\n'
              'State Bank → Jyothi → PVS → Lalbagh → Ladyhill → '
              'Kottara → Kuloor → Surathkal → Mulki → Padubidri → '
              'Nandikoor → Belman → Nitte → Anekere → Karkala',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (learnedRoutes.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No routes learned yet. Track a journey first!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${learnedRoutes.length} route(s) learned! Select below.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildRouteSelector() {
    // Extract unique origins and destinations from learned routes
    final origins = learnedRoutes
        .map((r) => r['origin_name'] as String)
        .toSet()
        .toList()
      ..sort();

    final destinations = selectedOrigin != null
        ? (learnedRoutes
            .where((r) => r['origin_name'] == selectedOrigin)
            .map((r) => r['destination_name'] as String)
            .toSet()
            .toList()
          ..sort())
        : <String>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Your Journey',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'From (Origin)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place, color: Colors.green),
              ),
              value: selectedOrigin,
              items: origins.map((origin) {
                final routeCount = learnedRoutes
                    .where((r) => r['origin_name'] == origin)
                    .length;
                return DropdownMenuItem(
                  value: origin,
                  child: Text(
                      '$origin ($routeCount route${routeCount > 1 ? 's' : ''})'),
                );
              }).toList(),
              onChanged: origins.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        selectedOrigin = value;
                        selectedDestination = null;
                        showSuggestions = false;
                      });
                    },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'To (Destination)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place, color: Colors.red),
              ),
              value: selectedDestination,
              items: destinations.map((dest) {
                final route = learnedRoutes.firstWhere(
                  (r) =>
                      r['origin_name'] == selectedOrigin &&
                      r['destination_name'] == dest,
                );
                final confidence = ((route['confidence_score'] as double) * 100)
                    .toStringAsFixed(0);
                final journeyCount = route['journey_count'] as int;
                return DropdownMenuItem(
                  value: dest,
                  child: Text('$dest ($confidence% conf, $journeyCount trips)'),
                );
              }).toList(),
              onChanged: selectedOrigin == null || destinations.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        selectedDestination = value;
                        showSuggestions = false;
                      });
                    },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: selectedOrigin != null && selectedDestination != null
                    ? _generateSuggestions
                    : null,
                icon: const Icon(Icons.route),
                label: const Text('Get Smart Suggestions'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfo() {
    if (selectedRoute == null) return const SizedBox();

    final routeName = selectedRoute!['route_name'] as String;
    final journeyCount = selectedRoute!['journey_count'] as int;
    final confidence = ((selectedRoute!['confidence_score'] as double) * 100)
        .toStringAsFixed(0);
    final avgDuration = selectedRoute!['avg_duration_minutes'] as int?;
    final avgDistance = selectedRoute!['avg_distance_km'] as double?;

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    routeName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip('$confidence% Confidence', Icons.verified),
                _buildInfoChip('$journeyCount Trips', Icons.history),
                if (avgDuration != null)
                  _buildInfoChip('~$avgDuration min', Icons.schedule),
                if (avgDistance != null)
                  _buildInfoChip('~${avgDistance.toStringAsFixed(1)} km',
                      Icons.straighten),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildSuggestedStops() {
    if (suggestedStops.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No intermediate stops found on this route',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Stops Along Your Route',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (selectedAlerts.isNotEmpty)
                  Chip(
                    label: Text('${selectedAlerts.length} selected'),
                    backgroundColor: Colors.blue.shade100,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: suggestedStops.length,
            itemBuilder: (context, index) {
              final stop = suggestedStops[index];
              final stopName = stop['stop_name'] as String;
              final sequence = stop['stop_sequence'] as int;
              final dwellSeconds = stop['avg_dwell_seconds'] as int?;
              final distanceFromPrev =
                  stop['avg_distance_from_prev_km'] as double?;

              final isSelected = selectedAlerts.contains(stopName);

              return CheckboxListTile(
                value: isSelected,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      selectedAlerts.add(stopName);
                    } else {
                      selectedAlerts.remove(stopName);
                    }
                  });
                },
                title: Text(
                  stopName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stop #$sequence'),
                    if (distanceFromPrev != null)
                      Text(
                          '${distanceFromPrev.toStringAsFixed(1)} km from previous stop'),
                    if (dwellSeconds != null)
                      Text('Avg stop time: ${dwellSeconds}s'),
                  ],
                ),
                secondary: CircleAvatar(
                  child: Text('$sequence'),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: selectedAlerts.isEmpty ? null : _activateAlerts,
                icon: const Icon(Icons.notifications_active),
                label: Text(
                  'Activate ${selectedAlerts.length} Alert${selectedAlerts.length != 1 ? 's' : ''}',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showJourneyHistory() async {
    final journeys = await _routeService.getJourneyHistory();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            AppBar(
              title: const Text('Journey History'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: journeys.isEmpty
                  ? const Center(child: Text('No journeys recorded yet'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: journeys.length,
                      itemBuilder: (context, index) {
                        final journey = journeys[index];
                        final startTime = DateTime.fromMillisecondsSinceEpoch(
                            journey['start_time'] as int);
                        final endTime = journey['end_time'] != null
                            ? DateTime.fromMillisecondsSinceEpoch(
                                journey['end_time'] as int)
                            : null;
                        final duration = endTime != null
                            ? endTime.difference(startTime).inMinutes
                            : null;

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('${index + 1}'),
                          ),
                          title: Text(journey['route_name'] ?? 'Unknown Route'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date: ${_formatDate(startTime)}'),
                              if (duration != null)
                                Text('Duration: $duration min'),
                              if (journey['total_distance_km'] != null)
                                Text(
                                    'Distance: ${(journey['total_distance_km'] as double).toStringAsFixed(1)} km'),
                              Text('Stops: ${journey['total_stops']}'),
                            ],
                          ),
                          trailing: journey['is_complete'] == 1
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : const Icon(Icons.pending, color: Colors.orange),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLearnedRoutes() async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            AppBar(
              title: const Text('Learned Routes'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: learnedRoutes.isEmpty
                  ? const Center(child: Text('No routes learned yet'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: learnedRoutes.length,
                      itemBuilder: (context, index) {
                        final route = learnedRoutes[index];
                        final confidence =
                            ((route['confidence_score'] as double) * 100)
                                .toStringAsFixed(0);

                        return ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: _getConfidenceColor(
                                route['confidence_score'] as double),
                            child: Text(
                              '$confidence%',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white),
                            ),
                          ),
                          title: Text(route['route_name'] as String),
                          subtitle: Text(
                            'Traveled ${route['journey_count']} time${route['journey_count'] > 1 ? 's' : ''}',
                          ),
                          children: [
                            ListTile(
                              title: Text(
                                'Stops: ${route['stop_sequence']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _routeService.dispose();
    super.dispose();
  }
}
