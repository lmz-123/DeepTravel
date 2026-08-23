enum DiscoveryPermissionState {
  granted,
  requestable,
  deniedForever,
  serviceDisabled,
}

enum DiscoveryLocationFailureReason {
  denied,
  deniedForever,
  serviceDisabled,
  timeout,
  unavailable,
}

class DiscoveryLocationFailure implements Exception {
  const DiscoveryLocationFailure(this.reason);

  final DiscoveryLocationFailureReason reason;
}

class DiscoveryLocationSample {
  const DiscoveryLocationSample({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.locality,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final String? locality;
}

abstract interface class CurrentLocationSource {
  Future<DiscoveryPermissionState> permissionState();

  Future<DiscoveryLocationSample> currentPosition({
    required bool requestPermission,
  });
}
