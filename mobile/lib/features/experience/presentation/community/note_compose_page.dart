import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../domain/community_models.dart';
import '../active_tour_controller.dart';
import '../experience_providers.dart';
import '../widgets/discovery_art.dart';
import 'notes_controller.dart';
import 'notes_widgets.dart';
import '../route_manual/route_companion_entry.dart';
import '../travel/guide_preparation.dart';
import '../travel/preparation_visuals.dart';

final notePhotoPickerProvider = Provider<Future<List<String>> Function()>(
    (ref) => () async => (await ImagePicker()
            .pickMultiImage(imageQuality: 90, maxWidth: 2400, maxHeight: 2400))
        .map((file) => file.path)
        .toList());

class NoteComposePage extends ConsumerStatefulWidget {
  const NoteComposePage({super.key, this.fragmentId, this.initialCategory});
  final CommunityCategory? initialCategory;
  final String? fragmentId;
  @override
  ConsumerState<NoteComposePage> createState() => _NoteComposePageState();
}

class _NoteComposePageState extends ConsumerState<NoteComposePage> {
  final _body = TextEditingController();
  final _title = TextEditingController();
  final _items = <GuidePreparationItem>[const GuidePreparationItem('')];
  bool _publishing = false;
  bool _guidePhotos = false;
  bool get _guide => _category == CommunityCategory.guide;
  bool get _validGuide =>
      !_guide ||
      (_title.text.trim().isNotEmpty &&
          _items.isNotEmpty &&
          _items.every((i) => i.title.trim().isNotEmpty));
  final _photos = <String>[];
  final _persistedPhotos = <String>{};
  String? _fragment, _user;
  String _idempotency = const Uuid().v4();
  CommunityCategory _category = CommunityCategory.onSite;
  int _selectedPhoto = -1;
  bool _allowExit = false, _leaving = false;
  bool get _hasChanges =>
      !_saved &&
      (_body.text.trim().isNotEmpty ||
          _photos.isNotEmpty ||
          _title.text.trim().isNotEmpty ||
          _items.any((i) => i.title.isNotEmpty || i.body.isNotEmpty));
  bool _loading = true, _busy = false, _picking = false, _saved = false;
  String get _draftKey => 'community_draft_${_user ?? 'demo'}';
  @override
  void initState() {
    super.initState();
    _user = ref.read(currentUserIdProvider);
    _fragment = widget.fragmentId;
    _category = widget.initialCategory ?? CommunityCategory.onSite;
    _restore();
  }

  Future<void> _restore() async {
    try {
      final data = await ref.read(tourStoreProvider).readJson(_draftKey);
      if (!mounted || _user != ref.read(currentUserIdProvider)) return;
      if (data != null && data['body'] is String) {
        _body.text = data['body'] as String;
        _title.text = data['title'] as String? ?? '';
        if (data['preparation_items'] is List) {
          _items
            ..clear()
            ..addAll((data['preparation_items'] as List).whereType<Map>().map(
                (i) => GuidePreparationItem.fromJson(
                    Map<String, dynamic>.from(i))));
          if (_items.isEmpty) _items.add(const GuidePreparationItem(''));
        }
        _fragment =
            widget.fragmentId ?? data['fragment'] as String? ?? _fragment;
        _idempotency = data['idempotency'] as String? ?? _idempotency;
        _category =
            widget.initialCategory ?? CommunityCategory.parse(data['category']);
        for (final path
            in (data['photos'] as List? ?? []).whereType<String>()) {
          if (await File(path).exists()) {
            if (!mounted || _user != ref.read(currentUserIdProvider)) return;
            _photos.add(path);
            _persistedPhotos.add(path);
          }
        }
        _saved = true;
      }
    } catch (_) {
      if (mounted) noteNotice(context, '草稿暂时无法读取');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final path in _photos.where((p) => !_persistedPhotos.contains(p))) {
      _deletePhoto(path);
    }
    _body.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _deletePhoto(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Future<void> _store() async {
    if (_user != ref.read(currentUserIdProvider)) return;
    final photos = List<String>.of(_photos);
    await ref.read(tourStoreProvider).saveJson(_draftKey, {
      'body': _body.text,
      'title': _title.text,
      'preparation_items': _items.map((i) => i.toJson()).toList(),
      'fragment': _fragment,
      'category': _category.id,
      'photos': List.of(_photos),
      'idempotency': _idempotency
    });
    for (final path in _persistedPhotos.difference(photos.toSet())) {
      await _deletePhoto(path);
    }
    _persistedPhotos
      ..clear()
      ..addAll(photos);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _store();
      if (mounted) {
        setState(() => _saved = true);
        noteNotice(context, '草稿已保存');
      }
    } catch (_) {
      if (mounted) noteNotice(context, '草稿未能保存，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _publishing = false;
        });
      }
    }
  }

  Future<void> _pickPhoto(int max) async {
    if (_picking || _photos.length >= max) return;
    setState(() => _picking = true);
    try {
      final paths = await ref.read(notePhotoPickerProvider)();
      if (paths.isEmpty ||
          !mounted ||
          _user != ref.read(currentUserIdProvider)) {
        return;
      }
      final root = await getApplicationSupportDirectory();
      final owner = sha256.convert(utf8.encode(_user ?? 'demo')).toString();
      final dir = Directory('${root.path}/community_drafts/$owner');
      await dir.create(recursive: true);
      final remaining = max - _photos.length;
      for (final path in paths.take(remaining)) {
        final extension = path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
        final copied = await File(path)
            .copy('${dir.path}/${const Uuid().v4()}.$extension');
        if (!mounted || _user != ref.read(currentUserIdProvider)) {
          await copied.delete();
          return;
        }
        setState(() {
          _photos.add(copied.path);
          _selectedPhoto = _photos.length - 1;
          _saved = false;
        });
      }
      if (paths.length > remaining && mounted) {
        noteNotice(context, '最多添加 $max 张照片');
      }
    } catch (_) {
      if (mounted) noteNotice(context, '照片未能添加，请重试');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _leave() async {
    if (_busy || _picking || _leaving) return;
    _leaving = true;
    try {
      if (_hasChanges) {
        final save = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
                  backgroundColor: notePaper,
                  shape: const RoundedRectangleBorder(),
                  title: Text('把这则见闻留下？', style: noteSerif(23)),
                  content: Text('保存草稿，下次继续写。',
                      style: noteSans(12, color: noteQuiet)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const Text('继续写')),
                    TextButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const Text('保存并返回'))
                  ],
                ));
        if (save != true || !mounted) return;
        await _store();
      }
      if (!mounted) return;
      setState(() => _allowExit = true);
      // Let PopScope publish canPop before asking the router to pop.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/?tab=community');
          }
        }
      });
    } catch (_) {
      if (mounted) noteNotice(context, '草稿未能保存，请重试');
    } finally {
      _leaving = false;
    }
  }

  Future<void> _publish(CommunityPolicy policy) async {
    if (_busy ||
        !policy.enabled ||
        !_validGuide ||
        _fragment == null ||
        _body.text.trim().isEmpty) {
      return;
    }
    if (_photos.length > math.min(9, policy.maxMedia)) {
      noteNotice(context, '最多添加 ${math.min(9, policy.maxMedia)} 张照片');
      return;
    }
    setState(() {
      _busy = true;
      _publishing = true;
    });
    try {
      await _store();
      if (!mounted || _user != ref.read(currentUserIdProvider)) return;
      final repo = ref.read(experienceRepositoryProvider);
      await repo.shareCommunityPost(
          _fragment!,
          CommunityPostDraft(
              category: _category,
              title: _guide ? _title.text.trim() : null,
              preparationItems: _guide ? List.of(_items) : const [],
              idempotencyKey: _idempotency,
              body: _body.text.trim(),
              photoPaths: List.of(_photos)));
      if (!mounted || _user != ref.read(currentUserIdProvider)) return;
      // A successful publish is final even if subsequent local cleanup fails.
      try {
        await ref.read(tourStoreProvider).saveJson(_draftKey, {});
      } catch (_) {}
      for (final path in _photos) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      if (!mounted) return;
      ref.read(notesCityProvider.notifier).select(null);
      ref.invalidate(notesFeedProvider);
      ref.invalidate(routeGuidesProvider);
      context.go('/?tab=community');
      noteNotice(context, '见闻已发布');
    } catch (_) {
      if (mounted) noteNotice(context, '发布未成功，内容已保留，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _publishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserIdProvider, (old, value) {
      if (old != value) context.go('/?tab=community');
    });
    final placesState = ref.watch(notesPlacesProvider);
    final policyState = ref.watch(notesPolicyProvider);
    final policy = policyState.value;
    final max = math.min(600, policy?.bodyMaxLength ?? 600);
    final places = placesState.value ?? <CommunityPlace>[];
    final place = places.where((p) => p.fragmentId == _fragment).firstOrNull;
    if (_guide) return _guidePage(policy, places, place, max);
    return PopScope(
        canPop: !_busy && !_picking && (!_hasChanges || _allowExit),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: NoteScaffold(
            navigationEnabled: !_busy,
            showNavigation: false,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NoteTop('返回',
                  onBack: _leave,
                  title: '写见闻',
                  trailing: NotePublishAction(
                      key: const ValueKey('note-publish'),
                      publishing: _publishing,
                      onTap: _busy ||
                              _loading ||
                              _picking ||
                              policy == null ||
                              !policy.enabled ||
                              place == null ||
                              !_validGuide ||
                              _body.text.trim().isEmpty
                          ? null
                          : () => _publish(policy))),
              if (!_guide) ...[
                const SizedBox(height: 7),
                Text('A NOTE TO REMEMBER',
                    style: noteItalic(10).copyWith(letterSpacing: 1)),
                const SizedBox(height: 8),
                Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: '留一则见闻'),
                    ]),
                    style: noteSerif(32)),
              ],
              if (_loading)
                const Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(
                        strokeWidth: 1, color: noteQuiet))
              else ...[
                const SizedBox(height: 25),
                Container(
                    decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: noteLine))),
                    child: Row(children: [
                      for (final entry in [
                        CommunityCategory.viewpoint,
                        CommunityCategory.onSite,
                        CommunityCategory.experience,
                        CommunityCategory.guide
                      ].asMap().entries)
                        Expanded(
                            child: NoteButton(
                                label: entry.value.label,
                                selected: _category == entry.value,
                                onTap: _busy
                                    ? null
                                    : () => setState(() {
                                          _category = entry.value;
                                          _saved = false;
                                        }),
                                child: SizedBox(
                                    height: 67,
                                    child: Stack(children: [
                                      Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('0${entry.key + 1}',
                                                style: noteItalic(11)),
                                            const SizedBox(height: 8),
                                            Text(entry.value.label,
                                                style: noteSerif(16,
                                                    color:
                                                        _category == entry.value
                                                            ? noteRed
                                                            : noteInk))
                                          ]),
                                      if (_category == entry.value)
                                        Positioned(
                                            left: 0,
                                            bottom: 0,
                                            child: Container(
                                                width: 35,
                                                height: 2,
                                                color: noteRed))
                                    ])))),
                    ])),
                const SizedBox(height: 20),
                ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 160),
                    child: TextField(
                        key: const ValueKey('note-compose-body'),
                        controller: _body,
                        enabled: !_busy,
                        maxLength: max,
                        minLines: 4,
                        maxLines: null,
                        style: noteSerif(17, height: 2),
                        onChanged: (_) => setState(() => _saved = false),
                        decoration: InputDecoration(
                            hintText: '这里有什么，让你想多停留一会儿？',
                            hintStyle: noteSerif(17,
                                color: const Color(0xff958c7d), height: 2),
                            filled: false,
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10)))),
                Row(children: [
                  NoteButton(
                      label: '存草稿',
                      onTap: _busy || _picking ? null : _save,
                      child: SizedBox(
                          height: 44,
                          child: Center(
                              child: Text(_saved ? '已存草稿' : '存草稿',
                                  style: noteSans(11, color: noteQuiet))))),
                  const Spacer(),
                  Text('${_body.text.characters.length} / $max',
                      style: noteItalic(11))
                ]),
                const SizedBox(height: 20),
                _photoEditor(math.min(9, policy?.maxMedia ?? 9)),
                const SizedBox(height: 24),
                _row(
                    '关联地点',
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerRight,
                            child: NoteButton(
                                label: '选择关联地点',
                                onTap: _busy || places.isEmpty
                                    ? null
                                    : () async {
                                        final selected = await Navigator.of(
                                                context)
                                            .push<String>(MaterialPageRoute(
                                                builder: (_) => NotePlacePicker(
                                                    places: places,
                                                    selected: _fragment)));
                                        if (selected != null && mounted) {
                                          setState(() {
                                            _fragment = selected;
                                            _saved = false;
                                          });
                                        }
                                      },
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                            Text(place?.routeTitle ?? '选择地点',
                                                style: noteSans(12)),
                                            if (place != null)
                                              Text(place.name,
                                                  textAlign: TextAlign.right,
                                                  style: noteSans(11,
                                                      color: noteQuiet)),
                                            Text(
                                                noteDistanceLabel(noteDistance(
                                                    place,
                                                    ref
                                                        .watch(
                                                            notesLocationProvider)
                                                        .value)),
                                                style: noteSans(11,
                                                    color: noteRed)),
                                          ])),
                                      const SizedBox(width: 6),
                                      const DiscoveryIcon(
                                          DiscoveryMark.arrowRight,
                                          size: 14)
                                    ]))))),
                if (placesState.hasError)
                  NoteFailure(
                      '地点暂时无法读取', () => ref.invalidate(notesPlacesProvider)),
                _row('谁可以看', Text('公开', style: noteSans(11, color: noteQuiet))),
                if (policyState.hasError)
                  NoteFailure(
                      '发布设置暂时无法读取', () => ref.invalidate(notesPolicyProvider)),
                if (policy?.enabled == false)
                  Text('见闻分享暂未开放', style: noteSans(12, color: noteQuiet)),
                const SizedBox(height: 24)
              ]
            ])));
  }

  Future<void> _chooseGuidePlace(List<CommunityPlace> places) async {
    if (_busy || places.isEmpty) return;
    final selected = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => NotePlacePicker(places: places, selected: _fragment)));
    if (selected != null && mounted) {
      setState(() {
        _fragment = selected;
        _saved = false;
      });
    }
  }

  Widget _guidePage(CommunityPolicy? policy, List<CommunityPlace> places,
          CommunityPlace? place, int max) =>
      PopScope(
          canPop: !_busy && !_picking && (!_hasChanges || _allowExit),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _leave();
          },
          child: PreparationScaffold(
              title: '分享见闻',
              onBack: _leave,
              trailing: PreparationLink(_publishing ? '发布中' : '发布',
                  key: const ValueKey('note-publish'),
                  pencil: true,
                  busy: _publishing,
                  onTap: _busy ||
                          _picking ||
                          _loading ||
                          policy?.enabled != true ||
                          place == null ||
                          !_validGuide ||
                          _body.text.trim().isEmpty
                      ? null
                      : () => _publish(policy!)),
              footer: Row(children: [
                NoteButton(
                    label: '存草稿',
                    onTap: _busy || _picking ? null : _save,
                    child: SizedBox(
                        height: 44,
                        child: Center(
                            child: Text(_saved ? '已存草稿' : '存草稿',
                                style: noteSans(11, color: noteQuiet))))),
                const SizedBox(width: 18),
                NoteButton(
                    label: '添加照片',
                    onTap: _busy || _picking
                        ? null
                        : () => setState(() => _guidePhotos = !_guidePhotos),
                    child: SizedBox(
                        height: 44,
                        child: Center(
                            child: Text('照片 ${_photos.length}',
                                style: noteSans(11, color: noteQuiet))))),
                const Spacer(),
                PreparationLink('查看地点',
                    icon: DiscoveryMark.arrowRight,
                    onTap: _busy || place == null
                        ? null
                        : () => context.push('/route/${place.routeSlug}')),
              ]),
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 1, color: noteQuiet))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          SizedBox(
                              height: 22,
                              child: Row(children: [
                                NoteButton(
                                    label: '切换见闻类型',
                                    onTap: _busy
                                        ? null
                                        : () => showModalBottomSheet<void>(
                                            context: context,
                                            backgroundColor: notePaper,
                                            builder: (sheet) => SafeArea(
                                                child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            23),
                                                    child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          for (final category
                                                              in [
                                                            CommunityCategory
                                                                .viewpoint,
                                                            CommunityCategory
                                                                .onSite,
                                                            CommunityCategory
                                                                .experience,
                                                            CommunityCategory
                                                                .guide
                                                          ])
                                                            ListTile(
                                                                contentPadding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                title: Text(
                                                                    category
                                                                        .label,
                                                                    style: noteSerif(
                                                                        18,
                                                                        color: category ==
                                                                                _category
                                                                            ? preparationRed
                                                                            : noteInk)),
                                                                onTap: () {
                                                                  Navigator.pop(
                                                                      sheet);
                                                                  setState(() {
                                                                    _category =
                                                                        category;
                                                                    _saved =
                                                                        false;
                                                                  });
                                                                }),
                                                        ])))),
                                    child: Row(children: [
                                      Text('攻略',
                                          style: noteSans(11,
                                              color: preparationRed)),
                                      const SizedBox(width: 5),
                                      const DiscoveryIcon(DiscoveryMark.down,
                                          size: 11, color: preparationRed)
                                    ])),
                                const Spacer(),
                                Text('准备攻略',
                                    style: noteSans(11, color: noteQuiet)),
                              ])),
                          TextField(
                              key: const ValueKey('guide-title'),
                              controller: _title,
                              enabled: !_busy,
                              maxLength: policy?.titleMaxLength ?? 60,
                              maxLines: 1,
                              style: noteSerif(23, height: 1.7),
                              onChanged: (_) => setState(() => _saved = false),
                              decoration: _guideField('给攻略起个标题')),
                          TextField(
                              key: const ValueKey('note-compose-body'),
                              controller: _body,
                              enabled: !_busy,
                              maxLength: max,
                              minLines: 3,
                              maxLines: null,
                              style: noteSans(16, height: 1.7),
                              onChanged: (_) => setState(() => _saved = false),
                              decoration: _guideField('有哪些经验，想分享给下一位出发的人？')),
                          NoteButton(
                              label: '选择关联地点',
                              onTap: _busy || places.isEmpty
                                  ? null
                                  : () => _chooseGuidePlace(places),
                              child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  decoration: const BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(color: noteLine))),
                                  child: Row(children: [
                                    const DiscoveryIcon(DiscoveryMark.pin,
                                        size: 14, color: preparationRed),
                                    const SizedBox(width: 7),
                                    Expanded(
                                        child: Text(
                                            place?.routeTitle ?? '选择关联地点',
                                            style: noteSans(12))),
                                    Text(place?.cityName ?? '',
                                        style: noteSans(11, color: noteQuiet)),
                                  ]))),
                          _guideEditor(),
                          Text('发布后，别人可以把这份清单加入自己的准备。',
                              style: noteSans(11, color: noteQuiet)),
                          if (_guidePhotos || _photos.isNotEmpty)
                            Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: _photoEditor(
                                    math.min(9, policy?.maxMedia ?? 9))),
                          if (policy?.enabled == false)
                            Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text('见闻分享暂未开放',
                                    style: noteSans(12, color: noteQuiet))),
                          if (ref.watch(notesPlacesProvider).hasError)
                            NoteFailure('地点暂时无法读取',
                                () => ref.invalidate(notesPlacesProvider)),
                          if (ref.watch(notesPolicyProvider).hasError)
                            NoteFailure('发布设置暂时无法读取',
                                () => ref.invalidate(notesPolicyProvider)),
                        ])));

  InputDecoration _guideField(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: noteSans(16, color: noteQuiet),
      counterText: '',
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      border:
          const UnderlineInputBorder(borderSide: BorderSide(color: noteLine)),
      enabledBorder:
          const UnderlineInputBorder(borderSide: BorderSide(color: noteLine)),
      focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: preparationGreen)));

  Widget _guideEditor() => Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: preparationSheet,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('出发前准备',
                  style: noteSerif(18, weight: FontWeight.w500, height: 1.6))),
          Text('${_items.length} 项', style: noteSans(11, color: noteQuiet))
        ]),
        const SizedBox(height: 6),
        for (var i = 0; i < _items.length; i++)
          Container(
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: noteLine))),
              child: Row(children: [
                SizedBox(
                    width: 18,
                    child: Text('${i + 1}',
                        style: noteItalic(17, color: const Color(0xff7d856e)))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextFormField(
                        key: ValueKey('guide-item-$i-${_items.length}'),
                        initialValue: _items[i].title,
                        enabled: !_busy,
                        maxLength: 60,
                        maxLines: null,
                        style: noteSans(14, height: 1.7),
                        onChanged: (value) => setState(() {
                              _items[i] = GuidePreparationItem(value,
                                  body: _items[i].body);
                              _saved = false;
                            }),
                        decoration: const InputDecoration(
                            hintText: '需要准备什么',
                            isDense: true,
                            counterText: '',
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none))),
                SizedBox(
                    width: 36,
                    child: IconButton(
                        tooltip: '删除准备项',
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 44),
                        padding: EdgeInsets.zero,
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _items.removeAt(i);
                                  _saved = false;
                                }),
                        icon: const Icon(Icons.remove,
                            size: 15, color: noteQuiet))),
              ])),
        if (_items.length < 12)
          PreparationLink('添加准备事项',
              leadingIcon: true,
              icon: DiscoveryMark.plus,
              onTap: _busy
                  ? null
                  : () => setState(() {
                        _items.add(const GuidePreparationItem(''));
                        _saved = false;
                      })),
      ]));

  void _movePhoto(int destination) {
    setState(() {
      final path = _photos.removeAt(_selectedPhoto);
      _photos.insert(destination, path);
      _selectedPhoto = destination;
      _saved = false;
    });
  }

  Widget _photoEditor(int max) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('照片', style: noteSans(12, color: noteQuiet)),
          const Spacer(),
          Text('${_photos.length} / $max', style: noteItalic(13))
        ]),
        const SizedBox(height: 12),
        GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < _photos.length; i++)
                NoteButton(
                    label: '编辑第 ${i + 1} 张照片',
                    selected: _selectedPhoto == i,
                    onTap: _busy || _picking
                        ? null
                        : () => setState(() => _selectedPhoto = i),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.file(File(_photos[i]), fit: BoxFit.cover),
                      if (i == 0)
                        Positioned(
                            left: 0,
                            bottom: 0,
                            child: Container(
                                color: notePaper,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                child: Text('首图',
                                    style: noteSans(10, color: noteQuiet)))),
                      if (_selectedPhoto == i)
                        Positioned.fill(
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    border:
                                        Border.all(color: noteRed, width: 2)))),
                    ])),
              if (_photos.length < max)
                NoteButton(
                    label: '添加照片',
                    onTap: _busy || _picking ? null : () => _pickPhoto(max),
                    child: CustomPaint(
                        painter: const NoteDashedBorder(),
                        child: ColoredBox(
                            color: const Color(0x33b8b5a3),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const DiscoveryIcon(DiscoveryMark.plus,
                                      size: 20, color: noteQuiet),
                                  const SizedBox(height: 9),
                                  Text(_picking ? '正在添加' : '添加照片',
                                      style: noteSans(11, color: noteQuiet))
                                ])))),
            ]),
        if (_selectedPhoto >= 0 && _selectedPhoto < _photos.length)
          Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: noteLine))),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _photoTool('设为首图',
                        _selectedPhoto > 0 ? () => _movePhoto(0) : null),
                    _photoTool(
                        '前移',
                        _selectedPhoto > 0
                            ? () => _movePhoto(_selectedPhoto - 1)
                            : null),
                    _photoTool(
                        '后移',
                        _selectedPhoto < _photos.length - 1
                            ? () => _movePhoto(_selectedPhoto + 1)
                            : null),
                    _photoTool(
                        '删除',
                        () => setState(() {
                              final path = _photos.removeAt(_selectedPhoto);
                              if (!_persistedPhotos.contains(path)) {
                                _deletePhoto(path);
                              }
                              _selectedPhoto =
                                  math.min(_selectedPhoto, _photos.length - 1);
                              _saved = false;
                            })),
                  ])),
      ]);
  Widget _photoTool(String label, VoidCallback? tap) => NoteButton(
      label: label,
      onTap: _busy || _picking ? null : tap,
      child: SizedBox(
          height: 44,
          child: Center(
              child: Text(label,
                  style: noteSans(11,
                      color: label == '删除'
                          ? noteRed
                          : tap == null
                              ? noteLine
                              : noteInk)))));

  Widget _row(String title, Widget trailing) => Container(
      constraints: const BoxConstraints(minHeight: 63),
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: noteLine))),
      child: Row(children: [
        Text(title, style: noteSans(12)),
        const SizedBox(width: 14),
        if (trailing is! Expanded) const Spacer(),
        trailing
      ]));
}

class NotePlacePicker extends StatelessWidget {
  const NotePlacePicker({super.key, required this.places, this.selected});
  final List<CommunityPlace> places;
  final String? selected;
  @override
  Widget build(BuildContext context) => NoteScaffold(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const NoteTop('返回'),
        Text('选择地点。', style: noteSerif(32)),
        const SizedBox(height: 10),
        Text('这则见闻，发生在哪里？', style: noteSans(11, color: noteQuiet)),
        for (final slug in places.map((p) => p.routeSlug).toSet()) ...[
          Padding(
              padding: const EdgeInsets.only(top: 25, bottom: 8),
              child: Text(
                  '${places.firstWhere((p) => p.routeSlug == slug).cityName} · ${places.firstWhere((p) => p.routeSlug == slug).routeTitle}',
                  style: noteSerif(20))),
          for (final place in places.where((p) => p.routeSlug == slug))
            NoteButton(
                label: place.name,
                selected: selected == place.fragmentId,
                onTap: () => Navigator.pop(context, place.fragmentId),
                child: Container(
                    constraints: const BoxConstraints(minHeight: 62),
                    decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: noteLine))),
                    child: Row(children: [
                      Expanded(
                          child: Text(place.name,
                              style: noteSans(13,
                                  color: selected == place.fragmentId
                                      ? noteRed
                                      : noteInk))),
                      const SizedBox(width: 8),
                      DiscoveryIcon(
                          selected == place.fragmentId
                              ? DiscoveryMark.check
                              : DiscoveryMark.arrowUpRight,
                          size: 17,
                          color: selected == place.fragmentId
                              ? noteRed
                              : noteQuiet)
                    ])))
        ],
        const SizedBox(height: 24)
      ]));
}
