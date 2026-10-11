import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/data/place_repository.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/city_atlas.dart';
import 'package:jiandi/features/experience/presentation/places_controller.dart';
import 'city_atlas_test.dart' as fixture;

class _Repository implements PlaceRepository {
  final calls =
      <({PlaceQuery query, String? cursor, Completer<PlacePage> result})>[];
  int mapCalls = 0, briefCalls = 0;
  @override
  Future<PlacePage> page(PlaceQuery query, {String? cursor}) {
    final result = Completer<PlacePage>();
    calls.add((query: query, cursor: cursor, result: result));
    return result.future;
  }

  @override
  Future<PlacePage> markers(PlaceQuery query) async {
    mapCalls++;
    return PlacePage(items: [fixture.place('远处景点')], total: 1);
  }

  @override
  Future<RouteExperience> brief(String slug) async {
    briefCalls++;
    return fixture.place(slug);
  }
}

PlacePage _page(List<String> ids, [String? cursor]) => PlacePage(
    items: ids.map(fixture.place).toList(),
    total: 30,
    nextCursor: cursor,
    categories: const ['coast', 'streets']);

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    requests.add(options);
    return ResponseBody.fromString(
        jsonEncode({
          'data': {'items': [], 'total': 0, 'next_cursor': null}
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
      'network request passes 12-item cursor, filters and separate map endpoint',
      () async {
    final adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example/api/v1'))
      ..httpClientAdapter = adapter;
    final repository = ApiPlaceRepository(dio);
    const query = PlaceQuery('shenzhen',
        search: '海',
        category: 'coast',
        district: '盐田区',
        nearest: true,
        latitude: 22,
        longitude: 114);
    await repository.page(query, cursor: 'next');
    await repository.markers(query);
    expect(adapter.requests.first.queryParameters, {
      'q': '海',
      'category': 'coast',
      'district': '盐田区',
      'order': 'nearest',
      'latitude': 22.0,
      'longitude': 114.0,
      'limit': 12,
      'cursor': 'next'
    });
    expect(adapter.requests.last.path, '/cities/shenzhen/place-markers');
    expect(
        adapter.requests.last.queryParameters.containsKey('cursor'), isFalse);
  });

  test(
      'old city/filter responses cannot mix pages; duplicate requests and IDs are suppressed',
      () async {
    final repo = _Repository();
    final controller = PlacesController(repo);
    final first = controller.reload(const PlaceQuery('shenzhen'));
    repo.calls[0].result.complete(_page(['a'], 'next'));
    await first;
    final more = controller.loadMore();
    await controller.loadMore();
    expect(repo.calls.length, 2);
    expect(repo.calls.last.cursor, 'next');
    final changed =
        controller.reload(const PlaceQuery('zhuhai', category: 'coast'));
    repo.calls[2].result.complete(_page(['new'], 'second'));
    await changed;
    repo.calls[1].result.complete(_page(['old'], 'old-next'));
    await more;
    expect(controller.page!.items.map((r) => r.id), ['new']);
    final next = controller.loadMore();
    repo.calls[3].result.complete(_page(['new', 'next']));
    await next;
    expect(controller.page!.items.map((r) => r.id), ['new', 'next']);
    expect(controller.page!.nextCursor, isNull);
    controller.dispose();
  });

  test('failed next page preserves rows and cursor for retry', () async {
    final repo = _Repository();
    final controller = PlacesController(repo);
    final first = controller.reload(const PlaceQuery('shenzhen'));
    repo.calls[0].result.complete(_page(['a'], 'next'));
    await first;
    final more = controller.loadMore();
    repo.calls[1].result.completeError(Exception('offline'));
    await more;
    expect(controller.moreFailed, isTrue);
    expect(controller.page!.items.single.id, 'a');
    final retry = controller.loadMore();
    expect(repo.calls[2].cursor, 'next');
    repo.calls[2].result.complete(_page(['b']));
    await retry;
    expect(controller.page!.items.map((r) => r.id), ['a', 'b']);
    controller.dispose();
  });

  testWidgets(
      'real atlas requests list pages and fetches markers only in map mode',
      (tester) async {
    final repo = _Repository();
    await tester.pumpWidget(ProviderScope(
        overrides: [placeRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
                body: CityAtlas(
              citySlug: 'shenzhen',
              cityName: '深圳',
              routes: [fixture.place('旧目录')],
              saved: const {},
              busyFavorites: const {},
              onFavorite: (_) {},
              onOpen: (_) {},
              onBack: () {},
            )))));
    expect(repo.calls.length, 1);
    expect(repo.mapCalls, 0);
    repo.calls[0].result
        .complete(_page(List.generate(12, (i) => '景点$i'), 'next'));
    await tester.pumpAndSettle();
    expect(find.text('旧目录'), findsNothing);
    expect(find.text('30 处景点'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pump();
    expect(repo.calls.length, 2);
    repo.calls[1].result.complete(_page(['下一页']));
    await tester.pumpAndSettle();
    final scroll =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('地图'));
    await tester.pumpAndSettle();
    expect(repo.mapCalls, 1);
    expect(repo.briefCalls, 0);
    await tester.tap(find.byKey(const ValueKey('city-map-point-远处景点')));
    await tester.pumpAndSettle();
    expect(repo.briefCalls, 1);
    expect(find.text('城市故事。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
