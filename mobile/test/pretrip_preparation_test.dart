import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/pretrip_preparation_service.dart';
import 'package:jiandi/features/experience/domain/city_story.dart';

void main() {
  test('offline preparation verifies resources and never keeps failed files',
      () async {
    final directory = await Directory.systemTemp.createTemp('jiandi-pretrip-');
    addTearDown(() => directory.delete(recursive: true));
    final bytesByPath = <String, List<int>>{
      '/good': utf8.encode('verified audio'),
      '/bad': utf8.encode('truncated'),
    };
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(Response<List<int>>(
        requestOptions: options,
        statusCode: 200,
        data: bytesByPath[options.path],
      )),
    ));
    final service = PretripPreparationService(
      dio,
      directoryProvider: () async => directory,
    );
    final goodBytes = bytesByPath['/good']!;
    final resources = [
      OfflineStoryResource(
        id: 'story:audio',
        kind: 'audio',
        url: '/good',
        version: 'v1',
        sizeBytes: goodBytes.length,
        checksumSha256: sha256.convert(goodBytes).toString(),
      ),
      OfflineStoryResource(
        id: 'story-two:audio',
        kind: 'audio',
        url: '/bad',
        version: 'v1',
        sizeBytes: 999,
        checksumSha256: sha256.convert(utf8.encode('expected')).toString(),
      ),
    ];

    final first = await service.prepare(resources);
    expect(first.preparedCount, 1);
    expect(first.failures.keys, contains('story-two:audio'));
    expect(
      directory.listSync().whereType<File>().where(
            (file) => !file.path.endsWith('.download'),
          ),
      hasLength(1),
    );
    expect(
      directory.listSync().whereType<File>().map((file) => file.path),
      everyElement(isNot(endsWith('.download'))),
    );

    final removed = await service.remove(resources);
    expect(removed, 1);
    expect(directory.listSync(), isEmpty);
  });
}
