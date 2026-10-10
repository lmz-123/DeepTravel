import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../domain/city_map.dart';
export '../domain/city_map.dart';

final _geometry = <String, List<CityAtlasDistrict>>{};

/// Bundled maps remain an offline fallback for older installations and outages.
Future<List<CityAtlasDistrict>> loadCityAtlasDistricts(String city) async {
  if (_geometry.containsKey(city)) return _geometry[city]!;
  final path = 'assets/maps/$city.geojson';
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  if (!manifest.listAssets().contains(path)) return const [];
  return _geometry[city] =
      parseCityMap(jsonDecode(await rootBundle.loadString(path)));
}

/// Stable subscriptions prevent every animation frame from fetching a new map.
class CityMapGeometryView extends StatefulWidget {
  const CityMapGeometryView(
      {required this.city,
      required this.builder,
      this.updates,
      this.revision,
      super.key});
  final String city;
  final CityMapUpdates? updates;
  final Object? revision;
  final Widget Function(List<CityAtlasDistrict>) builder;
  @override
  State<CityMapGeometryView> createState() => _CityMapGeometryViewState();
}

class _CityMapGeometryViewState extends State<CityMapGeometryView> {
  late Stream<List<CityAtlasDistrict>> _stream;
  void _load() {
    _stream = widget.updates?.call(widget.city) ??
        Stream.fromFuture(loadCityAtlasDistricts(widget.city));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CityMapGeometryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city ||
        oldWidget.updates != widget.updates ||
        oldWidget.revision != widget.revision) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CityAtlasDistrict>>(
      key: ValueKey(widget.city),
      stream: _stream,
      builder: (context, snapshot) =>
          widget.builder(snapshot.data ?? const []));
}
