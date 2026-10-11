import 'package:dio/dio.dart';
import '../domain/models.dart';

const placeCategories = {
  'coast': '海边',
  'nature': '山野',
  'streets': '街巷',
  'architecture': '建筑',
  'park': '公园',
  'other': '其他',
};

class PlaceQuery {
  const PlaceQuery(this.city,
      {this.search = '',
      this.category = '',
      this.district = '',
      this.nearest = false,
      this.latitude,
      this.longitude});
  final String city, search, category, district;
  final bool nearest;
  final double? latitude, longitude;
  Map<String, dynamic> get parameters => {
        if (search.isNotEmpty) 'q': search,
        if (category.isNotEmpty) 'category': category,
        if (district.isNotEmpty) 'district': district,
        'order': nearest ? 'nearest' : 'recommended',
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

class PlacePage {
  const PlacePage(
      {required this.items,
      required this.total,
      this.nextCursor,
      this.categories = const [],
      this.districts = const []});
  final List<RouteExperience> items;
  final int total;
  final String? nextCursor;
  final List<String> categories, districts;
  factory PlacePage.fromJson(Map<String, dynamic> json) => PlacePage(
        items: (json['items'] as List)
            .map((r) => placeFromJson(Map<String, dynamic>.from(r)))
            .toList(),
        total: json['total'] as int,
        nextCursor: json['next_cursor'] as String?,
        categories: List<String>.from(json['categories'] ?? []),
        districts: List<String>.from(json['districts'] ?? []),
      );
}

RouteExperience placeFromJson(Map<String, dynamic> data) =>
    RouteExperience.fromJson({
      'subtitle': '',
      'description': '',
      'duration_minutes': 0,
      'distance_km': 0,
      'difficulty': '',
      'theme': '',
      'hero_image': '',
      'content_status': 'published',
      ...data,
    });

abstract interface class PlaceRepository {
  Future<PlacePage> page(PlaceQuery query, {String? cursor});
  Future<PlacePage> markers(PlaceQuery query);
  Future<RouteExperience> brief(String slug);
}

class ApiPlaceRepository implements PlaceRepository {
  ApiPlaceRepository(this.dio);
  final Dio dio;
  @override
  Future<PlacePage> page(PlaceQuery query, {String? cursor}) async {
    final response = await dio.get(
        '/cities/${Uri.encodeComponent(query.city)}/places',
        queryParameters: {
          ...query.parameters,
          'limit': 12,
          if (cursor != null) 'cursor': cursor
        });
    return PlacePage.fromJson(Map<String, dynamic>.from(response.data['data']));
  }

  @override
  Future<PlacePage> markers(PlaceQuery query) async {
    final response = await dio.get(
        '/cities/${Uri.encodeComponent(query.city)}/place-markers',
        queryParameters: query.parameters);
    return PlacePage.fromJson(Map<String, dynamic>.from(response.data['data']));
  }

  @override
  Future<RouteExperience> brief(String slug) async {
    final response = await dio.get('/places/${Uri.encodeComponent(slug)}');
    return placeFromJson(Map<String, dynamic>.from(response.data['data']));
  }
}
