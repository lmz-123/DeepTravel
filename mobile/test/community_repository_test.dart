import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:jiandi/features/experience/data/api_experience_repository.dart';
import 'package:jiandi/features/experience/domain/community_models.dart';

void main() {
  test(
      'API community contract parses pages, authenticates media and builds multipart',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'));
    final requests = <RequestOptions>[];
    FormData? publishedForm;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      if (options.data is FormData) publishedForm = options.data as FormData;
      final response = switch (options.path) {
        '/policies/community' => {'data': _policy},
        '/journeys/journey-1/fragments/fragment-1/community-posts' =>
          options.method == 'GET'
              ? {
                  'data': {
                    'items': [_post],
                    'next_cursor': 'next-page',
                  }
                }
              : {'data': _post},
        '/community-posts/post-1' => {'data': _post},
        '/community-posts/post-1/likes' => {
            'data': {
              'items': [
                {'display_name': '旅行者乙', 'avatar': 'default'}
              ],
              'next_cursor': null,
            }
          },
        '/community-posts/post-1/comments' => {
            'data': {
              'items': [_comment],
              'next_cursor': null,
            }
          },
        '/community-posts/post-1/like' => {
            'data': {'viewer_has_liked': true, 'like_count': 4}
          },
        '/community-media/media-1' => <String, Object>{},
        _ => throw StateError('unexpected ${options.method} ${options.path}'),
      };
      if (options.path == '/community-media/media-1') {
        handler.resolve(Response<List<int>>(
          requestOptions: options,
          statusCode: 200,
          data: [1, 2, 3],
        ));
      } else {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: response,
        ));
      }
    }));
    final repository = ApiExperienceRepository(dio, _Auth(dio));
    final temporary = await Directory.systemTemp.createTemp('community-test-');
    addTearDown(() => temporary.delete(recursive: true));
    final photo = File('${temporary.path}/photo.jpg')
      ..writeAsBytesSync([1, 2, 3]);

    final policy = await repository.communityPolicy();
    final feed = await repository.communityFeed(
      'journey-1',
      'fragment-1',
      category: CommunityCategory.viewpoint,
    );
    final detail = await repository.communityPost('post-1');
    final likers = await repository.communityLikers('post-1');
    final comments = await repository.communityComments('post-1');
    final created = await repository.createCommunityPost(
      'journey-1',
      'fragment-1',
      CommunityPostDraft(
        category: CommunityCategory.viewpoint,
        idempotencyKey: 'publish-key',
        title: '标题',
        body: '正文',
        photoPaths: [photo.path],
        evidenceIds: const ['evidence-1'],
      ),
    );
    final like = await repository.setCommunityLike('post-1', true);
    final bytes = await repository.communityMediaBytes(detail.media.single);

    expect(policy.maxMedia, 4);
    expect(feed.nextCursor, 'next-page');
    expect(feed.items.single.id, 'post-1');
    expect(detail.author.displayName, '旅行者甲');
    expect(likers.items.single.displayName, '旅行者乙');
    expect(comments.items.single.body, '补充一句');
    expect(created.id, 'post-1');
    expect(like.likeCount, 4);
    expect(bytes, [1, 2, 3]);
    expect(
      requests.every((request) =>
          request.headers['Authorization'] == 'Bearer community-token'),
      isTrue,
    );
    expect(requests[1].queryParameters['category'], 'viewpoint');
    expect(
      publishedForm!.fields.any((field) =>
          field.key == 'evidence_ids[]' && field.value == 'evidence-1'),
      isTrue,
    );
    expect(publishedForm!.files.single.key, 'photos[]');
    expect(requests.last.responseType, ResponseType.bytes);
  });
}

class _Auth extends AuthRepository {
  _Auth(super.dio);
  @override
  String? get token => 'community-token';
}

const _policy = {
  'enabled': true,
  'categories': [
    {'id': 'viewpoint', 'label': '经典机位'}
  ],
  'title_max_length': 60,
  'body_max_length': 1200,
  'comment_max_length': 300,
  'max_media': 4,
  'allowed_mime_types': ['image/jpeg'],
  'report_reasons': ['other'],
  'private_source_remains_private': true,
  'community_copy_is_independent': true,
};

const _post = {
  'id': 'post-1',
  'fragment_id': 'fragment-1',
  'category': 'viewpoint',
  'title': '标题',
  'body': '正文',
  'author': {'display_name': '旅行者甲', 'avatar': 'default'},
  'media': [
    {
      'id': 'media-1',
      'url': '/api/v1/community-media/media-1',
      'mime_type': 'image/jpeg',
      'width': 10,
      'height': 10,
      'position': 0,
    }
  ],
  'like_count': 3,
  'comment_count': 1,
  'viewer_has_liked': false,
  'viewer_is_author': true,
  'created_at': '2026-08-23T10:00:00+00:00',
};

const _comment = {
  'id': 'comment-1',
  'post_id': 'post-1',
  'body': '补充一句',
  'author': {'display_name': '旅行者乙', 'avatar': 'default'},
  'viewer_is_author': false,
  'created_at': '2026-08-23T10:01:00+00:00',
};
