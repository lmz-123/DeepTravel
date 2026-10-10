import 'dart:ui';

class CityAtlasDistrict {
  const CityAtlasDistrict(this.name, this.center, this.polygons);
  final String name;
  final Offset center;
  final List<List<List<Offset>>> polygons;
}

typedef CityMapUpdates = Stream<List<CityAtlasDistrict>> Function(String city);

List<CityAtlasDistrict> parseCityMap(dynamic data) {
  if (data is! Map ||
      data['type'] != 'FeatureCollection' ||
      data['features'] is! List ||
      (data['features'] as List).isEmpty ||
      (data['features'] as List).length > 200) {
    throw const FormatException('Invalid city map');
  }
  var points = 0;
  Offset point(dynamic value) {
    if (value is! List ||
        value.length < 2 ||
        value[0] is! num ||
        value[1] is! num) {
      throw const FormatException('Invalid map coordinate');
    }
    final x = (value[0] as num).toDouble(), y = (value[1] as num).toDouble();
    if (!x.isFinite || !y.isFinite || x.abs() > 180 || y.abs() > 85) {
      throw const FormatException('Invalid map coordinate');
    }
    if (++points > 120000) throw const FormatException('Map too large');
    return Offset(x, y);
  }

  return (data['features'] as List).map((feature) {
    final props = feature['properties'];
    final name = props['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid district');
    }
    final geometry = feature['geometry'];
    final type = geometry['type'];
    if (type != 'Polygon' && type != 'MultiPolygon') {
      throw const FormatException('Invalid boundary');
    }
    final polygons = type == 'Polygon'
        ? [geometry['coordinates']]
        : geometry['coordinates'] as List;
    if (polygons.isEmpty) throw const FormatException('Empty boundary');
    return CityAtlasDistrict(
        name,
        point(props['center']),
        polygons.map<List<List<Offset>>>((polygon) {
          if ((polygon as List).isEmpty) {
            throw const FormatException('Empty polygon');
          }
          return polygon.map<List<Offset>>((ring) {
            final result = (ring as List).map(point).toList();
            if (result.length < 4 || result.first != result.last) {
              throw const FormatException('Open boundary');
            }
            return result;
          }).toList();
        }).toList());
  }).toList();
}
