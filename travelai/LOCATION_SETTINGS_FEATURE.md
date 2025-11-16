# Default Location Settings Feature

## Overview
The app now includes a comprehensive location settings system that allows users to configure default starting locations for all features, making the navigation experience more personalized and convenient.

## Features Implemented

### 1. Location Settings Service (`services/location_settings_service.dart`)
- **Purpose**: Manages persistent storage of location preferences
- **Key Features**:
  - Save and retrieve default locations
  - Feature-specific location settings (Map View, Track Page, etc.)
  - GPS preference toggle
  - Preset location library (Mangalore, Bangalore, Delhi, Mumbai)
  - Custom location support with coordinates

### 2. Enhanced Settings Page (`settings_page.dart`)
A complete redesign with modern UI and comprehensive features:

#### Main Sections:
1. **GPS Preference Toggle**
   - Enable/disable automatic GPS location usage
   - When enabled, app tries to use current location first
   - Falls back to saved location if GPS unavailable

2. **Default Location**
   - Set a global default location for all features
   - Quick access to preset cities
   - Custom location input with coordinates

3. **Feature-Specific Locations**
   - **Map View Location**: Custom starting location for Map View
   - Each feature can have its own default location
   - Falls back to global default if not set

4. **Preset Locations**
   - **Use Current Location**: GPS-based (0, 0 marker)
   - **Mangalore**: 12.9141, 74.8560 (Default)
   - **Bangalore**: 12.9716, 77.5946
   - **Delhi**: 28.6139, 77.2090
   - **Mumbai**: 19.0760, 72.8777

5. **Custom Location Input**
   - Enter location name
   - Latitude (-90 to 90)
   - Longitude (-180 to 180)
   - Zoom level (10-18)
   - Validation and error handling

6. **Reset to Defaults**
   - One-click reset to Mangalore
   - Confirmation dialog to prevent accidental resets

### 3. Enhanced Map View Page (`map_view_page.dart`)
- **Smart Location Loading**:
  1. Checks GPS preference setting
  2. Attempts to get current location if enabled
  3. Falls back to saved default location
  4. 5-second timeout for GPS acquisition
  5. Graceful error handling

- **User Experience**:
  - Loading indicator while fetching location
  - Settings button in app bar for quick access
  - My Location enabled on map
  - Smooth camera positioning

### 4. Updated Main Navigation
- Added `/settings` route for deep linking
- Settings accessible from Map View page
- Consistent navigation throughout app

## Usage Guide

### For Users:

#### Setting a Default Location:
1. Open the app
2. Tap "Settings" button on home screen
3. Tap "Default Location" card
4. Choose from preset locations OR tap "Custom Location"
5. For custom: Enter name, latitude, longitude, and zoom level
6. Tap "Save"

#### Using GPS Location:
1. Go to Settings
2. Toggle "Use Current Location" switch to ON
3. Grant location permissions when prompted
4. App will automatically use your GPS location

#### Setting Map View Location:
1. Open Settings
2. Scroll to "Feature-Specific Locations"
3. Tap "Map View Location"
4. Select desired location
5. Open Map View to see it take effect

#### Resetting to Defaults:
1. Open Settings
2. Scroll to "Actions" section
3. Tap "Reset to Defaults"
4. Confirm in dialog
5. All locations reset to Mangalore

### For Developers:

#### Adding Default Location to New Features:

```dart
import 'services/location_settings_service.dart' as settings;

// Get default location
final defaultLocation = await settings.LocationSettingsService.getDefaultLocation();

// Use coordinates
final lat = defaultLocation.latitude;
final lng = defaultLocation.longitude;
final zoom = defaultLocation.zoom;

// Check GPS preference
final useGPS = await settings.LocationSettingsService.getUseCurrentLocation();
```

#### Creating Feature-Specific Settings:

```dart
// Save feature location
await settings.LocationSettingsService.saveTrackPageLocation(location);

// Get feature location (falls back to default)
final location = await settings.LocationSettingsService.getTrackPageLocation();
```

#### Creating Custom Location:

```dart
final customLocation = settings.LocationSettings(
  latitude: 12.9141,
  longitude: 74.8560,
  locationName: 'My Office',
  zoom: 15.0,
);
```

## Technical Details

### Data Persistence
- Uses `shared_preferences` package
- Stores locations as comma-separated strings: `lat,lng,name,zoom`
- Keys: `default_location`, `map_view_location`, `track_page_location`, `use_current_location`

### Location Format
```dart
class LocationSettings {
  final double latitude;
  final double longitude;
  final String locationName;
  final double zoom;
}
```

### GPS Handling
- 5-second timeout for location acquisition
- Checks location service enabled
- Verifies location permissions
- Graceful fallback to saved location
- Error handling for all scenarios

## UI/UX Highlights

### Design Features:
- **Material Design 3** styling
- **Gradient backgrounds** for visual appeal
- **Card-based layout** for organization
- **Bottom sheet pickers** for selection
- **Haptic feedback** on interactions
- **SnackBar notifications** for confirmations
- **Loading indicators** for async operations
- **Validation dialogs** for user input

### Accessibility:
- Clear labels and descriptions
- Icon indicators for location types
- Confirmation dialogs for destructive actions
- Error messages with guidance
- Loading states with progress indicators

## Benefits

1. **Personalization**: Users can set their home city as default
2. **Convenience**: No need to search for location every time
3. **Flexibility**: GPS or preset locations based on preference
4. **Feature-Specific**: Different defaults for different features
5. **Persistence**: Settings saved across app restarts
6. **Validation**: Prevents invalid coordinates
7. **User-Friendly**: Beautiful, intuitive interface

## Future Enhancements

Potential additions:
- [ ] Recent locations history
- [ ] Favorite locations list
- [ ] Location search with autocomplete
- [ ] Import/export settings
- [ ] Multiple profile support
- [ ] Location sharing between devices
- [ ] Geofencing alerts
- [ ] Weather-based location suggestions

## Testing Checklist

- [x] Settings page loads without errors
- [x] Default location saved and retrieved correctly
- [x] GPS toggle works properly
- [x] Preset locations display correct coordinates
- [x] Custom location input validates properly
- [x] Map View uses saved location
- [x] Reset to defaults works correctly
- [x] Haptic feedback on interactions
- [x] SnackBar notifications appear
- [x] Loading states display properly
- [x] Navigation between settings and features works
- [x] Permissions handled gracefully

## Known Limitations

1. GPS timeout is 5 seconds (may need adjustment for slow connections)
2. Preset locations limited to 5 cities (easily expandable)
3. No location search/autocomplete yet (planned)
4. Custom locations not validated against actual map boundaries

## Conclusion

This feature significantly enhances the user experience by providing:
- **Control**: Users decide where the app starts
- **Efficiency**: Faster navigation to familiar places
- **Flexibility**: GPS or preset locations
- **Polish**: Professional UI/UX design

The implementation follows Flutter best practices with proper state management, error handling, and user feedback mechanisms.
