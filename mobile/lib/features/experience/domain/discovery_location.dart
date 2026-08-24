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
    this.localityCandidates = const [],
    this.accuracyMeters,
    this.providerStrategy = 'unknown',
    this.isCached = false,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final String? locality;
  final List<String> localityCandidates;
  final double? accuracyMeters;
  final String providerStrategy;
  final bool isCached;
}

abstract interface class CurrentLocationSource {
  Future<DiscoveryPermissionState> permissionState();

  Future<DiscoveryLocationSample> currentPosition({
    required bool requestPermission,
  });
}
