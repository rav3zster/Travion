# Coordinate Picker Feature

## Overview
The Map View now includes an interactive coordinate picker that allows you to tap anywhere on the map to retrieve coordinates and easily copy them for use in other features.

## Features

### 1. **Tap to Get Coordinates**
- Simply tap anywhere on the map
- A marker appears at the tapped location
- A bottom panel slides up showing the coordinates

### 2. **Multiple Copy Options**

#### Copy Both Coordinates
- Quick copy button in the main coordinate display
- Copies in format: `12.914100, 74.856000`
- Perfect for pasting into navigation apps or settings

#### Copy Individual Values
- **Latitude Only**: Copy just the latitude value
- **Longitude Only**: Copy just the longitude value
- Useful when you need to enter values separately

#### Copy Detailed Format
- Copies in labeled format:
  ```
  Latitude: 12.914100
  Longitude: 74.856000
  ```
- Ideal for documentation or sharing

### 3. **Current Location Coordinates**
- Tap the GPS icon (📍) in the app bar
- Instantly get your current location coordinates
- Camera automatically zooms to your position
- Marker placed at your current location

### 4. **Visual Feedback**
- **Haptic Feedback**: Feel a vibration when copying
- **SnackBar Notifications**: Visual confirmation of what was copied
- **Color-Coded Cards**: 
  - Blue: Full coordinates
  - Green: Latitude
  - Orange: Longitude

### 5. **Interactive Panel**
- Drag handle for easy dismissal
- Close button to hide the panel
- Clear markers when closing
- Stays visible until you dismiss it

## How to Use

### Getting Coordinates from Map:
1. Open **Map View** from the home screen
2. **Tap anywhere** on the map
3. Bottom panel appears with coordinates
4. Choose your copy option:
   - Tap **copy icon** next to full coordinates
   - Tap **copy icon** next to latitude
   - Tap **copy icon** next to longitude
   - Tap **"Copy Detailed Format"** button

### Getting Your Current Location:
1. Open **Map View**
2. Tap the **📍 GPS icon** in the top-right
3. Grant location permission if prompted
4. Your coordinates appear in the panel
5. Copy as needed

### Using Coordinates in Settings:
1. Copy coordinates from Map View
2. Go to **Settings**
3. Tap "Custom Location"
4. **Paste** latitude and longitude
5. Enter a name and save

## UI Components

### Coordinate Panel Structure:
```
┌─────────────────────────────────┐
│  ▔▔▔▔  (Drag Handle)           │
│                                  │
│  📍 Location Coordinates    ✕   │
├─────────────────────────────────┤
│                                  │
│  ┌────────────────────────┐    │
│  │ Coordinates         📋 │    │
│  │ 12.914100, 74.856000   │    │
│  └────────────────────────┘    │
│                                  │
│  ┌──────────┐  ┌──────────┐   │
│  │Latitude📋│  │Longitude📋│   │
│  │12.914100 │  │74.856000 │   │
│  └──────────┘  └──────────┘   │
│                                  │
│  [ 📤 Copy Detailed Format ]    │
├─────────────────────────────────┤
│ ℹ️ Tap map to get coordinates   │
└─────────────────────────────────┘
```

## Coordinate Precision
- All coordinates displayed to **6 decimal places**
- Precision: ~0.1 meters (approximately 4 inches)
- Format: Decimal degrees (DD.DDDDDD)

## Integration Points

### Works With:
1. **Settings → Custom Location**: Paste coordinates directly
2. **Track Page → Destination**: Use for setting destinations
3. **Bus Stops Page**: Add custom bus stop locations
4. **Route Planning**: Define waypoints and routes

## Technical Details

### Clipboard Operations:
```dart
// Full coordinates
"12.914100, 74.856000"

// Individual latitude
"12.914100"

// Individual longitude
"74.856000"

// Detailed format
"Latitude: 12.914100\nLongitude: 74.856000"
```

### Haptic Feedback:
- **Medium Impact**: When copying both coordinates
- **Light Impact**: When copying individual values
- Provides tactile confirmation of action

### Visual States:
- **No Selection**: Map only, no panel
- **Location Selected**: Marker + Bottom panel
- **Current Location**: GPS marker + Panel + Camera animation

## Benefits

1. **Quick Access**: Get coordinates from any point instantly
2. **Flexible Copying**: Multiple format options
3. **User-Friendly**: Visual cards and clear labels
4. **Accurate**: 6 decimal place precision
5. **Integrated**: Works seamlessly with other features
6. **Accessible**: Large tap targets and clear feedback

## Use Cases

### Navigation Setup:
- Set home location in settings
- Define favorite locations
- Plan routes with waypoints

### Bus Stop Management:
- Add custom bus stops
- Update existing locations
- Share locations with others

### Travel Planning:
- Mark points of interest
- Save parking locations
- Plan meeting points

### Development/Testing:
- Test specific coordinates
- Verify location accuracy
- Debug GPS features

## Tips

1. **Long Press**: For more accurate placement, zoom in first
2. **Current Location**: Use GPS button for exact current position
3. **Multiple Copies**: Copy different formats for different uses
4. **Settings Integration**: Directly use in custom location setup
5. **Dismiss Panel**: Tap close (✕) or tap outside to dismiss

## Accessibility

- **Large Buttons**: Easy to tap copy buttons
- **Clear Labels**: All elements clearly labeled
- **Visual Feedback**: SnackBars confirm actions
- **Haptic Feedback**: Physical confirmation
- **Color Coding**: Different colors for different values

## Future Enhancements

Potential additions:
- [ ] Save favorite locations
- [ ] History of copied coordinates
- [ ] Distance measurement between two points
- [ ] Coordinate format conversion (DMS, UTM, etc.)
- [ ] Share via messaging apps
- [ ] Reverse geocoding (address lookup)
- [ ] Elevation data display
- [ ] Map overlay with coordinate grid

## Troubleshooting

**Panel not appearing?**
- Make sure you're tapping directly on the map
- Check that the map has fully loaded

**Copy not working?**
- Ensure clipboard permissions are granted
- Check SnackBar for confirmation message

**GPS not working?**
- Grant location permissions in settings
- Enable location services on device
- Check GPS signal strength

**Marker not visible?**
- Zoom in to see marker clearly
- Panel will still show coordinates

## Summary

The Coordinate Picker feature makes it incredibly easy to:
✅ Get coordinates from any map location
✅ Copy in multiple formats
✅ Use coordinates across the app
✅ Share locations with others
✅ Set up custom locations quickly

Perfect for travelers, developers, and anyone who needs precise location data!
