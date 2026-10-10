import 'dart:convert';

import 'package:flutter/services.dart';

class CityAtlasDistrict {
  const CityAtlasDistrict(this.name, this.center, this.polygons);
  final String name;
  final Offset center;
  final List<List<List<Offset>>> polygons;
}

final _geometry = <String, List<CityAtlasDistrict>>{};

/// City assets use catalog slugs; adding a map requires no renderer changes.
Future<List<CityAtlasDistrict>> loadCityAtlasDistricts(String city) async {
  if (_geometry.containsKey(city)) return _geometry[city]!;
  final path = 'assets/maps/$city.geojson';
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  if (!manifest.listAssets().contains(path)) return const [];
  final data =
      jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;
  return _geometry[city] = (data['features'] as List).map((feature) {
    final props = feature['properties'];
    final center = props['center'] as List;
    final geometry = feature['geometry'];
    final polygons = geometry['type'] == 'Polygon'
        ? [geometry['coordinates']]
        : geometry['coordinates'] as List;
    return CityAtlasDistrict(
      props['name'] as String,
      Offset((center[0] as num).toDouble(), (center[1] as num).toDouble()),
      polygons
          .map<List<List<Offset>>>((polygon) => (polygon as List)
              .map<List<Offset>>((ring) => (ring as List)
                  .map<Offset>((point) => Offset((point[0] as num).toDouble(),
                      (point[1] as num).toDouble()))
                  .toList())
              .toList())
          .toList(),
    );
  }).toList();
}
