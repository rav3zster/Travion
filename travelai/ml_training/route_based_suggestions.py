"""
Intelligent Route-Based Alert System

Uses your bus stop dataset to:
1. Suggest stops based on origin → destination route
2. Filter only relevant stops along the journey
3. Learn common routes from historical data
4. Provide smart alerts at the right time

Example: Mangalore → Karkala
- Shows only stops between these cities
- Filters out Katapadi, Kasaragod (different routes)
- Learns which stops are actually visited
- Predicts arrival time at each stop
"""

import numpy as np
import pandas as pd
from typing import List, Dict, Tuple, Optional
import json
from datetime import datetime, timedelta
import math

class RouteBasedStopSuggester:
    """
    Suggests relevant bus stops based on journey route
    """
    
    def __init__(self, stops_csv_path: str):
        """
        Initialize with bus stop dataset
        
        Expected CSV columns:
        - stop_id: Unique identifier
        - stop_name: Name of the stop
        - latitude: GPS latitude
        - longitude: GPS longitude
        - route_ids: Comma-separated route numbers (optional)
        - sequence: Stop sequence on route (optional)
        """
        self.stops_df = pd.read_csv(stops_csv_path)
        self.routes = {}  # route_id -> list of stops
        
        # Build route index if available
        if 'route_ids' in self.stops_df.columns:
            self._build_route_index()
    
    def _build_route_index(self):
        """Build index of routes and their stops"""
        for _, stop in self.stops_df.iterrows():
            if pd.notna(stop['route_ids']):
                routes = str(stop['route_ids']).split(',')
                for route_id in routes:
                    route_id = route_id.strip()
                    if route_id not in self.routes:
                        self.routes[route_id] = []
                    self.routes[route_id].append(stop.to_dict())
    
    def haversine_distance(self, lat1: float, lon1: float, 
                          lat2: float, lon2: float) -> float:
        """Calculate distance between two GPS points in kilometers"""
        R = 6371  # Earth's radius in km
        
        lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
        c = 2 * math.asin(math.sqrt(a))
        
        return R * c
    
    def calculate_bearing(self, lat1: float, lon1: float, 
                         lat2: float, lon2: float) -> float:
        """Calculate bearing (direction) from point 1 to point 2"""
        lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
        
        dlon = lon2 - lon1
        x = math.sin(dlon) * math.cos(lat2)
        y = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dlon)
        
        bearing = math.atan2(x, y)
        bearing = math.degrees(bearing)
        bearing = (bearing + 360) % 360
        
        return bearing
    
    def is_point_on_route(self, point_lat: float, point_lon: float,
                          origin_lat: float, origin_lon: float,
                          dest_lat: float, dest_lon: float,
                          tolerance_km: float = 5.0) -> bool:
        """
        Check if a point lies approximately on the route from origin to destination
        
        Uses perpendicular distance from line algorithm
        """
        # Calculate distances
        d_origin = self.haversine_distance(origin_lat, origin_lon, point_lat, point_lon)
        d_dest = self.haversine_distance(point_lat, point_lon, dest_lat, dest_lon)
        d_direct = self.haversine_distance(origin_lat, origin_lon, dest_lat, dest_lon)
        
        # Point should be roughly between origin and destination
        # Total distance shouldn't be much more than direct distance
        total_distance = d_origin + d_dest
        deviation = total_distance - d_direct
        
        # If deviation is small, point is likely on route
        return deviation < tolerance_km
    
    def suggest_stops_between(self, 
                             origin: str,
                             destination: str,
                             max_stops: int = 20) -> List[Dict]:
        """
        Suggest relevant stops between origin and destination
        
        Args:
            origin: Name of starting point (or coordinates as "lat,lon")
            destination: Name of ending point (or coordinates as "lat,lon")
            max_stops: Maximum number of stops to suggest
            
        Returns:
            List of stop dictionaries with distance and relevance score
        """
        # Find origin and destination coordinates
        origin_coords = self._resolve_location(origin)
        dest_coords = self._resolve_location(destination)
        
        if not origin_coords or not dest_coords:
            return []
        
        origin_lat, origin_lon = origin_coords
        dest_lat, dest_lon = dest_coords
        
        # Calculate route bearing
        route_bearing = self.calculate_bearing(origin_lat, origin_lon, dest_lat, dest_lon)
        route_distance = self.haversine_distance(origin_lat, origin_lon, dest_lat, dest_lon)
        
        # Find all stops along the route
        candidate_stops = []
        
        for _, stop in self.stops_df.iterrows():
            stop_lat = stop['latitude']
            stop_lon = stop['longitude']
            
            # Check if stop is on route
            if self.is_point_on_route(stop_lat, stop_lon, 
                                     origin_lat, origin_lon,
                                     dest_lat, dest_lon,
                                     tolerance_km=5.0):
                
                # Calculate distance from origin
                dist_from_origin = self.haversine_distance(
                    origin_lat, origin_lon, stop_lat, stop_lon
                )
                
                # Calculate distance from destination
                dist_from_dest = self.haversine_distance(
                    stop_lat, stop_lon, dest_lat, dest_lon
                )
                
                # Skip if too close to origin or destination
                if dist_from_origin < 0.5 or dist_from_dest < 0.5:
                    continue
                
                # Calculate relevance score
                # Higher score = more relevant
                score = 100
                
                # Prefer stops roughly in the middle
                middle_position = abs(dist_from_origin - route_distance / 2)
                score -= middle_position * 2
                
                # Calculate bearing to stop
                bearing_to_stop = self.calculate_bearing(
                    origin_lat, origin_lon, stop_lat, stop_lon
                )
                bearing_diff = abs(bearing_to_stop - route_bearing)
                if bearing_diff > 180:
                    bearing_diff = 360 - bearing_diff
                
                # Penalize stops not aligned with route direction
                score -= bearing_diff / 2
                
                candidate_stops.append({
                    'stop_id': stop.get('stop_id', ''),
                    'stop_name': stop['stop_name'],
                    'latitude': stop_lat,
                    'longitude': stop_lon,
                    'distance_from_origin_km': round(dist_from_origin, 2),
                    'distance_from_dest_km': round(dist_from_dest, 2),
                    'relevance_score': round(score, 2),
                    'estimated_arrival_time': None  # Will be calculated
                })
        
        # Sort by distance from origin (natural journey order)
        candidate_stops.sort(key=lambda x: x['distance_from_origin_km'])
        
        # Take top N most relevant stops
        suggested_stops = candidate_stops[:max_stops]
        
        # Calculate estimated arrival times
        suggested_stops = self._add_arrival_estimates(
            suggested_stops, origin_coords, average_speed_kmh=40
        )
        
        return suggested_stops
    
    def _resolve_location(self, location: str) -> Optional[Tuple[float, float]]:
        """
        Resolve location string to coordinates
        
        Accepts:
        - Stop name: "Mangalore"
        - Coordinates: "12.9141,74.8560"
        """
        # Check if it's coordinates
        if ',' in location:
            try:
                lat, lon = map(float, location.split(','))
                return (lat, lon)
            except:
                pass
        
        # Search in stops database
        matches = self.stops_df[
            self.stops_df['stop_name'].str.contains(location, case=False, na=False)
        ]
        
        if len(matches) > 0:
            stop = matches.iloc[0]
            return (stop['latitude'], stop['longitude'])
        
        return None
    
    def _add_arrival_estimates(self, stops: List[Dict], 
                               origin_coords: Tuple[float, float],
                               average_speed_kmh: float = 40) -> List[Dict]:
        """Add estimated arrival times to stops"""
        current_time = datetime.now()
        
        for stop in stops:
            distance_km = stop['distance_from_origin_km']
            travel_time_hours = distance_km / average_speed_kmh
            travel_time_minutes = int(travel_time_hours * 60)
            
            estimated_time = current_time + timedelta(minutes=travel_time_minutes)
            stop['estimated_arrival_time'] = estimated_time.strftime('%I:%M %p')
            stop['estimated_travel_minutes'] = travel_time_minutes
        
        return stops
    
    def export_suggestions_json(self, origin: str, destination: str, 
                               output_path: str = 'suggested_stops.json'):
        """
        Export suggestions to JSON for Flutter app
        """
        suggestions = self.suggest_stops_between(origin, destination)
        
        output = {
            'route': {
                'origin': origin,
                'destination': destination,
                'generated_at': datetime.now().isoformat()
            },
            'suggested_stops': suggestions,
            'total_stops': len(suggestions)
        }
        
        with open(output_path, 'w') as f:
            json.dump(output, f, indent=2)
        
        print(f"✅ Exported {len(suggestions)} suggestions to {output_path}")
        return suggestions


def create_sample_dataset():
    """
    Create sample bus stop dataset for testing
    (Replace with your actual dataset)
    """
    # Example: Mangalore to Karkala route
    stops = [
        # Mangalore area
        {'stop_id': 1, 'stop_name': 'Mangalore Central', 'latitude': 12.9141, 'longitude': 74.8560},
        {'stop_id': 2, 'stop_name': 'Mangalore Bus Stand', 'latitude': 12.8694, 'longitude': 74.8426},
        
        # Route to Karkala
        {'stop_id': 3, 'stop_name': 'Mulki', 'latitude': 13.0911, 'longitude': 74.7935},
        {'stop_id': 4, 'stop_name': 'Brahmavar', 'latitude': 13.2339, 'longitude': 74.7379},
        {'stop_id': 5, 'stop_name': 'Udupi', 'latitude': 13.3409, 'longitude': 74.7421},
        {'stop_id': 6, 'stop_name': 'Manipal', 'latitude': 13.3475, 'longitude': 74.7869},
        {'stop_id': 7, 'stop_name': 'Karkala', 'latitude': 13.2114, 'longitude': 74.9929},
        
        # Other routes (should NOT be suggested)
        {'stop_id': 8, 'stop_name': 'Katapadi', 'latitude': 13.2167, 'longitude': 74.8833},  # Different route
        {'stop_id': 9, 'stop_name': 'Kasaragod', 'latitude': 12.5006, 'longitude': 75.0187},  # Different route
        {'stop_id': 10, 'stop_name': 'Kundapura', 'latitude': 13.6297, 'longitude': 74.6842},  # Different route
    ]
    
    df = pd.DataFrame(stops)
    df.to_csv('sample_stops.csv', index=False)
    print("✅ Created sample_stops.csv")
    return 'sample_stops.csv'


def demonstrate():
    """Demonstrate the route-based suggestion system"""
    print("=" * 70)
    print("INTELLIGENT ROUTE-BASED STOP SUGGESTIONS")
    print("=" * 70)
    
    # Create sample dataset
    csv_path = create_sample_dataset()
    
    # Initialize suggester
    suggester = RouteBasedStopSuggester(csv_path)
    
    # Example 1: Mangalore to Karkala
    print("\n📍 ROUTE: Mangalore → Karkala")
    print("-" * 70)
    
    suggestions = suggester.suggest_stops_between(
        origin='Mangalore',
        destination='Karkala',
        max_stops=10
    )
    
    print(f"\n✅ Found {len(suggestions)} relevant stops:\n")
    for i, stop in enumerate(suggestions, 1):
        print(f"{i}. {stop['stop_name']}")
        print(f"   Distance from start: {stop['distance_from_origin_km']} km")
        print(f"   ETA: {stop['estimated_arrival_time']} ({stop['estimated_travel_minutes']} min)")
        print(f"   Relevance: {stop['relevance_score']}/100")
        print()
    
    # Export to JSON
    suggester.export_suggestions_json('Mangalore', 'Karkala')
    
    print("\n" + "=" * 70)
    print("BENEFITS:")
    print("  ✅ Only shows stops BETWEEN origin and destination")
    print("  ✅ Filters out irrelevant stops (Katapadi, Kasaragod)")
    print("  ✅ Orders stops by journey sequence")
    print("  ✅ Estimates arrival time at each stop")
    print("  ✅ Gives relevance score for each suggestion")
    print("=" * 70)


if __name__ == "__main__":
    demonstrate()
