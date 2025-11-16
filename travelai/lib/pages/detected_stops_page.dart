import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/detected_stop.dart';
import '../services/stop_detection_database.dart';

/// Page to display detected stops history
class DetectedStopsPage extends StatefulWidget {
  const DetectedStopsPage({super.key});

  @override
  State<DetectedStopsPage> createState() => _DetectedStopsPageState();
}

class _DetectedStopsPageState extends State<DetectedStopsPage> {
  List<DetectedStop> _stops = [];
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  DetectedStopType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    setState(() => _isLoading = true);

    try {
      final stops = _filterType == null
          ? await StopDetectionDatabase.instance.getRecentStops(30)
          : await StopDetectionDatabase.instance.getStopsByType(_filterType!);

      final stats = await StopDetectionDatabase.instance.getStopStatistics();

      setState(() {
        _stops = stops;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stops: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmStop(
      DetectedStop stop, DetectedStopType correctedType) async {
    final updatedStop = stop.copyWith(
      stopType: correctedType,
      userConfirmed: true,
      confidence: 1.0,
    );

    await StopDetectionDatabase.instance.updateStop(updatedStop);
    _loadStops();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stop updated to ${correctedType.name}')),
      );
    }
  }

  Future<void> _deleteStop(DetectedStop stop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Stop'),
        content: const Text('Are you sure you want to delete this stop?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && stop.id != null) {
      await StopDetectionDatabase.instance.deleteStop(stop.id!);
      _loadStops();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stop deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detected Stops'),
        actions: [
          PopupMenuButton<DetectedStopType?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (type) {
              setState(() => _filterType = type);
              _loadStops();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Stops'),
              ),
              ...DetectedStopType.values.map((type) => PopupMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Text(DetectedStop(
                          latitude: 0,
                          longitude: 0,
                          timestamp: DateTime.now(),
                          dwellTime: 0,
                          stopType: type,
                          confidence: 0,
                        ).stopTypeIcon),
                        const SizedBox(width: 8),
                        Text(DetectedStop(
                          latitude: 0,
                          longitude: 0,
                          timestamp: DateTime.now(),
                          dwellTime: 0,
                          stopType: type,
                          confidence: 0,
                        ).stopTypeName),
                      ],
                    ),
                  )),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStops,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_statistics != null) _buildStatisticsCard(),
                Expanded(
                  child:
                      _stops.isEmpty ? _buildEmptyState() : _buildStopsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildStatisticsCard() {
    final stats = _statistics!;
    final totalStops = stats['totalStops'] as int;
    final avgDwell = stats['averageDwellTime'] as double;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total Stops',
                  totalStops.toString(),
                  Icons.location_on,
                ),
                _buildStatItem(
                  'Avg Dwell',
                  '${avgDwell.toStringAsFixed(0)}s',
                  Icons.timer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No stops detected yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking to detect stops automatically',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildStopsList() {
    return ListView.builder(
      itemCount: _stops.length,
      itemBuilder: (context, index) {
        final stop = _stops[index];
        return _buildStopCard(stop);
      },
    );
  }

  Widget _buildStopCard(DetectedStop stop) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showStopDetails(stop),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    stop.stopTypeIcon,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.stopTypeName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          dateFormat.format(stop.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (stop.userConfirmed)
                    const Icon(Icons.check_circle, color: Colors.green)
                  else
                    Chip(
                      label: Text(
                        '${(stop.confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.blue[100],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.timer,
                    '${stop.dwellTime.toStringAsFixed(0)}s',
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.location_on,
                    '${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)}',
                  ),
                ],
              ),
              if (stop.notes != null && stop.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  stop.notes!,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  void _showStopDetails(DetectedStop stop) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  stop.stopTypeIcon,
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.stopTypeName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Confidence: ${(stop.confidence * 100).toStringAsFixed(1)}%',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Is this correct?', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: DetectedStopType.values
                  .where((type) => type != DetectedStopType.unknown)
                  .map((type) => ActionChip(
                        label: Text(DetectedStop(
                          latitude: 0,
                          longitude: 0,
                          timestamp: DateTime.now(),
                          dwellTime: 0,
                          stopType: type,
                          confidence: 0,
                        ).stopTypeName),
                        onPressed: () {
                          _confirmStop(stop, type);
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteStop(stop);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
