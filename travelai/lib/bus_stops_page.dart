import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'models/bus_stop.dart';
import 'services/bus_stop_service.dart';

class BusStopsPage extends StatefulWidget {
  const BusStopsPage({super.key});

  @override
  State<BusStopsPage> createState() => _BusStopsPageState();
}

class _BusStopsPageState extends State<BusStopsPage> {
  final BusStopService _service = BusStopService();
  List<BusStop> _busStops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBusStops();
  }

  Future<void> _loadBusStops() async {
    setState(() => _isLoading = true);
    final stops = await _service.loadBusStops();
    setState(() {
      _busStops = stops;
      _isLoading = false;
    });
  }

  Future<void> _addBusStop() async {
    final result = await showDialog<BusStop>(
      context: context,
      builder: (context) => const AddBusStopDialog(),
    );

    if (result != null) {
      await _service.addBusStop(result);
      _loadBusStops();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bus stop "${result.name}" added!')),
        );
      }
    }
  }

  Future<void> _deleteBusStop(BusStop stop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bus Stop'),
        content: Text('Are you sure you want to delete "${stop.name}"?'),
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

    if (confirmed == true) {
      await _service.removeBusStop(stop.id);
      _loadBusStops();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bus stop "${stop.name}" deleted')),
        );
      }
    }
  }

  Future<void> _loadSampleStops() async {
    final stops = BusStopService.getSampleBusStops();
    for (final stop in stops) {
      await _service.addBusStop(stop);
    }
    _loadBusStops();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample bus stops loaded!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Bus Stops'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBusStops,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'load_sample') {
                _loadSampleStops();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'load_sample',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Load Sample Stops'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _busStops.isEmpty
              ? _buildEmptyState()
              : _buildBusStopsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBusStop,
        icon: const Icon(Icons.add_location),
        label: const Text('Add Bus Stop'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bus_alert, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Bus Stops Yet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add bus stops to get alerts when you\'re approaching them during your journey.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSampleStops,
              icon: const Icon(Icons.download),
              label: const Text('Load Sample Stops'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusStopsList() {
    // Sort by sequence number
    _busStops.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _busStops.length,
      itemBuilder: (context, index) {
        final stop = _busStops[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          elevation: 3,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[700],
              child: Text(
                '${stop.sequenceNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              stop.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stop.description != null) ...[
                  const SizedBox(height: 4),
                  Text(stop.description!),
                ],
                const SizedBox(height: 4),
                Text(
                  'Lat: ${stop.latitude.toStringAsFixed(4)}, Lng: ${stop.longitude.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.blue),
                  onPressed: () => _showStopDetails(stop),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteBusStop(stop),
                ),
              ],
            ),
            isThreeLine: stop.description != null,
          ),
        );
      },
    );
  }

  void _showStopDetails(BusStop stop) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stop.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Stop Number', '#${stop.sequenceNumber}'),
            _buildDetailRow('Latitude', stop.latitude.toStringAsFixed(6)),
            _buildDetailRow('Longitude', stop.longitude.toStringAsFixed(6)),
            if (stop.description != null)
              _buildDetailRow('Description', stop.description!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class AddBusStopDialog extends StatefulWidget {
  const AddBusStopDialog({super.key});

  @override
  State<AddBusStopDialog> createState() => _AddBusStopDialogState();
}

class _AddBusStopDialogState extends State<AddBusStopDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _descController = TextEditingController();
  final _seqController = TextEditingController(text: '1');
  bool _useCurrentLocation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _descController.dispose();
    _seqController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location set!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Bus Stop'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Stop Name *',
                  hintText: 'e.g., Kottara Chowki',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g., Near market',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _useCurrentLocation,
                    onChanged: (value) {
                      setState(() => _useCurrentLocation = value ?? false);
                      if (value == true) {
                        _getCurrentLocation();
                      }
                    },
                  ),
                  const Text('Use current location'),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude *',
                  hintText: '12.8698',
                ),
                keyboardType: TextInputType.number,
                enabled: !_useCurrentLocation,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter latitude';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Invalid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lngController,
                decoration: const InputDecoration(
                  labelText: 'Longitude *',
                  hintText: '74.8428',
                ),
                keyboardType: TextInputType.number,
                enabled: !_useCurrentLocation,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter longitude';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Invalid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _seqController,
                decoration: const InputDecoration(
                  labelText: 'Sequence Number *',
                  hintText: '1',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter sequence number';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Invalid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final stop = BusStop(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _nameController.text.trim(),
                latitude: double.parse(_latController.text),
                longitude: double.parse(_lngController.text),
                description: _descController.text.trim().isEmpty
                    ? null
                    : _descController.text.trim(),
                sequenceNumber: int.parse(_seqController.text),
              );
              Navigator.pop(context, stop);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
