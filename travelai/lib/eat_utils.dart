String calculateEAT(double distanceMeters, double speedMetersPerSec) {
  if (speedMetersPerSec <= 0) return 'N/A';
  double timeSec = distanceMeters / speedMetersPerSec;
  int hours = (timeSec / 3600).floor();
  int minutes = ((timeSec % 3600) / 60).floor();

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  } else {
    return '${minutes}m';
  }
}
