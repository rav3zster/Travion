import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/location_settings_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  LocationSettings? _defaultLocation;
  LocationSettings? _mapViewLocation;
  bool _useCurrentLocation = true;
  bool _isLoading = true;
  String? _alarmSoundPath;
  String? _alarmExternalUri;
  AudioPlayer? _previewPlayer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final defaultLoc = await LocationSettingsService.getDefaultLocation();
    final mapViewLoc = await LocationSettingsService.getMapViewLocation();
    final useCurrentLoc = await LocationSettingsService.getUseCurrentLocation();
    final prefs = await SharedPreferences.getInstance();
    final soundPath = prefs.getString('alarm_sound_path');
    final externalUri = prefs.getString('alarm_external_uri');

    setState(() {
      _defaultLocation = defaultLoc;
      _mapViewLocation = mapViewLoc;
      _useCurrentLocation = useCurrentLoc;
      _alarmSoundPath = soundPath;
      _alarmExternalUri = externalUri;
      _isLoading = false;
    });
  }

  Future<void> _showLocationPicker({
    required String title,
    required Function(LocationSettings) onSelect,
    LocationSettings? currentSelection,
  }) async {
    final presets = LocationSettingsService.getPresetLocations();

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ...presets.map((location) => ListTile(
                    leading: Icon(
                      location.locationName == 'Use Current Location'
                          ? Icons.my_location
                          : Icons.location_on,
                      color: Theme.of(context).primaryColor,
                    ),
                    title: Text(location.locationName),
                    subtitle: location.locationName != 'Use Current Location'
                        ? Text(
                            '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}')
                        : const Text('Use GPS location when available'),
                    trailing:
                        currentSelection?.locationName == location.locationName
                            ? Icon(Icons.check,
                                color: Theme.of(context).primaryColor)
                            : null,
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(location);
                    },
                  )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_location, color: Colors.orange),
                title: const Text('Custom Location'),
                subtitle: const Text('Enter coordinates manually'),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomLocationDialog(onSelect);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomLocationDialog(
      Function(LocationSettings) onSelect) async {
    final latController = TextEditingController();
    final lonController = TextEditingController();
    final nameController = TextEditingController();
    final zoomController = TextEditingController(text: '12.0');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Location Name',
                  hintText: 'e.g., My Home',
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: latController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: 'e.g., 12.9141',
                  prefixIcon: Icon(Icons.north),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lonController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: 'e.g., 74.8560',
                  prefixIcon: Icon(Icons.east),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: zoomController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Zoom Level',
                  hintText: '10-18',
                  prefixIcon: Icon(Icons.zoom_in),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lon = double.tryParse(lonController.text);
              final zoom = double.tryParse(zoomController.text) ?? 12.0;
              final name = nameController.text.trim();

              if (lat != null &&
                  lon != null &&
                  name.isNotEmpty &&
                  lat >= -90 &&
                  lat <= 90 &&
                  lon >= -180 &&
                  lon <= 180) {
                Navigator.pop(context);
                onSelect(LocationSettings(
                  latitude: lat,
                  longitude: lon,
                  locationName: name,
                  zoom: zoom,
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid coordinates and name'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 2,
      ),
      body: ListView(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Theme.of(context).primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.settings, size: 48, color: Color(0xFF283593)),
                SizedBox(height: 12),
                Text(
                  'Location Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF283593),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Configure default locations for all features',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          ),

          // GPS Preference
          Card(
            margin: const EdgeInsets.all(16),
            child: SwitchListTile(
              secondary: const Icon(Icons.gps_fixed, color: Color(0xFF283593)),
              title: const Text(
                'Use Current Location',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle:
                  const Text('Automatically use GPS location when available'),
              value: _useCurrentLocation,
              activeColor: const Color(0xFF283593),
              onChanged: (value) async {
                await LocationSettingsService.setUseCurrentLocation(value);
                setState(() {
                  _useCurrentLocation = value;
                });
                if (mounted) {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(value
                          ? 'GPS location enabled'
                          : 'Using preset locations'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ),

          // Default Location Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'DEFAULT LOCATION',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading:
                  const Icon(Icons.location_city, color: Color(0xFF283593)),
              title: const Text(
                'Default Location',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _defaultLocation!.locationName == 'Use Current Location'
                    ? 'Using GPS location'
                    : '${_defaultLocation!.locationName}\n${_defaultLocation!.latitude.toStringAsFixed(4)}, ${_defaultLocation!.longitude.toStringAsFixed(4)}',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () {
                _showLocationPicker(
                  title: 'Select Default Location',
                  currentSelection: _defaultLocation,
                  onSelect: (location) async {
                    await LocationSettingsService.saveDefaultLocation(location);
                    setState(() {
                      _defaultLocation = location;
                    });
                    if (mounted) {
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Default location set to ${location.locationName}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),

          // Feature-specific Locations
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'FEATURE-SPECIFIC LOCATIONS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.map, color: Color(0xFF1976d2)),
              title: const Text(
                'Map View Location',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _mapViewLocation!.locationName == 'Use Current Location'
                    ? 'Using GPS location'
                    : '${_mapViewLocation!.locationName}\n${_mapViewLocation!.latitude.toStringAsFixed(4)}, ${_mapViewLocation!.longitude.toStringAsFixed(4)}',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () {
                _showLocationPicker(
                  title: 'Select Map View Location',
                  currentSelection: _mapViewLocation,
                  onSelect: (location) async {
                    await LocationSettingsService.saveMapViewLocation(location);
                    setState(() {
                      _mapViewLocation = location;
                    });
                    if (mounted) {
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Map View location set to ${location.locationName}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),

          // Reset Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'ACTIONS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text(
                'Reset to Defaults',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Reset all locations to Mangalore'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset to Defaults?'),
                    content: const Text(
                        'This will reset all location settings to Mangalore. Continue?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final mangalore = LocationSettings.mangalore;
                  await LocationSettingsService.saveDefaultLocation(mangalore);
                  await LocationSettingsService.saveMapViewLocation(mangalore);
                  await _loadSettings();
                  if (mounted) {
                    HapticFeedback.heavyImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All settings reset to default'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
          ),

          // Alarm / Notification Settings
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'ALARM & NOTIFICATIONS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.music_note, color: Color(0xFF283593)),
                  title: const Text('Alarm Sound'),
                  subtitle: Text(_alarmSoundPath ?? 'Use default app sound'),
                  trailing: IconButton(
                    icon: const Icon(Icons.upload_file),
                    onPressed: () async {
                      // Request storage permission where applicable
                      await Permission.storage.request();
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final path = result.files.single.path;
                        if (path != null) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('alarm_sound_path', path);
                          setState(() {
                            _alarmSoundPath = path;
                          });
                        }
                      }
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.link, color: Color(0xFF1976d2)),
                  title: const Text('External App / URI'),
                  subtitle: Text(
                      _alarmExternalUri ?? 'Optional: e.g., spotify:track:...'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final controller =
                          TextEditingController(text: _alarmExternalUri ?? '');
                      final uri = await showDialog<String?>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('External App URI'),
                          content: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText:
                                  'e.g., spotify:track:... or https://...',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, null),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(
                                  context, controller.text.trim()),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );

                      if (uri != null) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('alarm_external_uri', uri);
                        setState(() {
                          _alarmExternalUri = uri;
                        });
                      }
                    },
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Preview'),
                        onPressed: () async {
                          if (_alarmSoundPath != null &&
                              _alarmSoundPath!.isNotEmpty) {
                            _previewPlayer ??= AudioPlayer();
                            try {
                              await _previewPlayer!.stop();
                              await _previewPlayer!
                                  .play(DeviceFileSource(_alarmSoundPath!));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Unable to play file: $e')),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('No alarm sound selected')),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('alarm_sound_path');
                          await prefs.remove('alarm_external_uri');
                          await _previewPlayer?.stop();
                          setState(() {
                            _alarmSoundPath = null;
                            _alarmExternalUri = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Info Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF283593)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These settings will be used as default starting locations when you open different features of the app.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
