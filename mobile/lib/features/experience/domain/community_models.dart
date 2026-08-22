import 'dart:typed_data';

enum CommunityCategory {
  viewpoint('viewpoint', '经典机位'),
  experience('experience', '行走经验'),
  factSupplement('fact_supplement', '事实补充 · 旅行者内容'),
  onSite('on_site', '现场发现');

  const CommunityCategory(this.id, this.label);
  final String id;
  final String label;

  static CommunityCategory parse(Object? value) => values.firstWhere(
        (item) => item.id == value,
        orElse: () => CommunityCategory.onSite,
      );
}

class CommunityPolicy {
  const CommunityPolicy({
    required this.enabled,
    required this.categories,
    required this.titleMaxLength,
    required this.bodyMaxLength,
    required this.commentMaxLength,
    required this.maxMedia,
    required this.allowedMimeTypes,
    required this.reportReasons,
    required this.privateSourceRemainsPrivate,
    required this.communityCopyIsIndependent,
  });

  final bool enabled;
  final List<CommunityCategory> categories;
  final int titleMaxLength;
  final int bodyMaxLength;
  final int commentMaxLength;
  final int maxMedia;
  final List<String> allowedMimeTypes;
  final List<String> reportReasons;
  final bool privateSourceRemainsPrivate;
  final bool communityCopyIsIndependent;

  factory CommunityPolicy.fromJson(Map<String, dynamic> json) =>
      CommunityPolicy(
        enabled: json['enabled'] == true,
        categories: _maps(json['categories'])
            .map((item) => CommunityCategory.parse(item['id']))
            .toList(growable: false),
        titleMaxLength: _integer(json['title_max_length'], 60),
        bodyMaxLength: _integer(json['body_max_length'], 1200),
        commentMaxLength: _integer(json['comment_max_length'], 300),
        maxMedia: _integer(json['max_media'], 4),
        allowedMimeTypes: _strings(json['allowed_mime_types']),
        reportReasons: _strings(json['report_reasons']),
        privateSourceRemainsPrivate:
            json['private_source_remains_private'] == true,
        communityCopyIsIndependent:
            json['community_copy_is_independent'] == true,
      );
}

class CommunityAuthor {
  const CommunityAuthor({required this.displayName, required this.avatar});
  final String displayName;
  final String avatar;

  factory CommunityAuthor.fromJson(Map<String, dynamic> json) =>
      CommunityAuthor(
        displayName: _text(json['display_name']) ?? '见地旅行者',
        avatar: _text(json['avatar']) ?? 'default',
      );
}

class CommunityMedia {
  const CommunityMedia({
    required this.id,
    required this.url,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.position,
  });
  final String id;
  final String url;
  final String mimeType;
  final int width;
  final int height;
  final int position;

  factory CommunityMedia.fromJson(Map<String, dynamic> json) => CommunityMedia(
        id: _text(json['id']) ?? '',
        url: _text(json['url']) ?? '',
        mimeType: _text(json['mime_type']) ?? 'image/jpeg',
        width: _integer(json['width'], 1),
        height: _integer(json['height'], 1),
        position: _integer(json['position'], 0),
      );
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.fragmentId,
    required this.category,
    required this.author,
    required this.media,
    required this.likeCount,
    required this.commentCount,
    required this.viewerHasLiked,
    required this.viewerIsAuthor,
    required this.createdAt,
    this.title,
    this.body = '',
    this.bodyTruncated = false,
  });

  final String id;
  final String fragmentId;
  final CommunityCategory category;
  final String? title;
  final String body;
  final bool bodyTruncated;
  final CommunityAuthor author;
  final List<CommunityMedia> media;
  final int likeCount;
  final int commentCount;
  final bool viewerHasLiked;
  final bool viewerIsAuthor;
  final DateTime? createdAt;

  CommunityPost copyWith({
    int? likeCount,
    int? commentCount,
    bool? viewerHasLiked,
  }) =>
      CommunityPost(
        id: id,
        fragmentId: fragmentId,
        category: category,
        title: title,
        body: body,
        bodyTruncated: bodyTruncated,
        author: author,
        media: media,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        viewerHasLiked: viewerHasLiked ?? this.viewerHasLiked,
        viewerIsAuthor: viewerIsAuthor,
        createdAt: createdAt,
      );

  factory CommunityPost.fromJson(Map<String, dynamic> json) => CommunityPost(
        id: _text(json['id']) ?? '',
        fragmentId: _text(json['fragment_id']) ?? '',
        category: CommunityCategory.parse(json['category']),
        title: _text(json['title']),
        body: _text(json['body']) ?? '',
        bodyTruncated: json['body_truncated'] == true,
        author: CommunityAuthor.fromJson(_map(json['author'])),
        media: _maps(json['media'])
            .map(CommunityMedia.fromJson)
            .toList(growable: false),
        likeCount: _integer(json['like_count'], 0),
        commentCount: _integer(json['comment_count'], 0),
        viewerHasLiked: json['viewer_has_liked'] == true,
        viewerIsAuthor: json['viewer_is_author'] == true,
        createdAt: DateTime.tryParse(_text(json['created_at']) ?? ''),
      );
}

typedef CommunityPostSummary = CommunityPost;
typedef CommunityPostDetail = CommunityPost;

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.body,
    required this.author,
    required this.viewerIsAuthor,
    required this.createdAt,
  });
  final String id;
  final String postId;
  final String body;
  final CommunityAuthor author;
  final bool viewerIsAuthor;
  final DateTime? createdAt;

  factory CommunityComment.fromJson(Map<String, dynamic> json) =>
      CommunityComment(
        id: _text(json['id']) ?? '',
        postId: _text(json['post_id']) ?? '',
        body: _text(json['body']) ?? '',
        author: CommunityAuthor.fromJson(_map(json['author'])),
        viewerIsAuthor: json['viewer_is_author'] == true,
        createdAt: DateTime.tryParse(_text(json['created_at']) ?? ''),
      );
}

class CommunityPage<T> {
  const CommunityPage({required this.items, this.nextCursor});
  final List<T> items;
  final String? nextCursor;
  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

class CommunityLikeResult {
  const CommunityLikeResult({required this.liked, required this.likeCount});
  final bool liked;
  final int likeCount;

  factory CommunityLikeResult.fromJson(Map<String, dynamic> json) =>
      CommunityLikeResult(
        liked: json['viewer_has_liked'] == true,
        likeCount: _integer(json['like_count'], 0),
      );
}

class CommunityPostDraft {
  const CommunityPostDraft({
    required this.category,
    required this.idempotencyKey,
    this.title,
    this.body,
    this.photoPaths = const [],
    this.evidenceIds = const [],
  });
  final CommunityCategory category;
  final String idempotencyKey;
  final String? title;
  final String? body;
  final List<String> photoPaths;
  final List<String> evidenceIds;
}

class CommunityMediaBytes {
  const CommunityMediaBytes(this.media, this.bytes);
  final CommunityMedia media;
  final Uint8List bytes;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : const [];

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];

int _integer(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

String? _text(Object? value) {
  if (value is! String) return null;
  final result = value.trim();
  return result.isEmpty ? null : result;
}
