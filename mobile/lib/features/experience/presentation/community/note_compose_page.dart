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

final notePhotoPickerProvider = Provider<Future<String?> Function()>((ref) =>
    () async => (await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 90,
            maxWidth: 2400,
            maxHeight: 2400))
        ?.path);

class NoteComposePage extends ConsumerStatefulWidget {
  const NoteComposePage({super.key, this.fragmentId});
  final String? fragmentId;
  @override
  ConsumerState<NoteComposePage> createState() => _NoteComposePageState();
}

class _NoteComposePageState extends ConsumerState<NoteComposePage> {
  final _body = TextEditingController();
  final _photos = <String>[];
  final _persistedPhotos = <String>{};
  String? _fragment, _user;
  String _idempotency = const Uuid().v4();
  late DateTime _visit;
  bool _loading = true, _busy = false, _picking = false, _saved = false;
  String get _draftKey => 'community_draft_${_user ?? 'demo'}';
  @override
  void initState() {
    super.initState();
    _visit = ref.read(notesNowProvider)();
    _user = ref.read(currentUserIdProvider);
    _fragment = widget.fragmentId;
    _restore();
  }

  Future<void> _restore() async {
    try {
      final data = await ref.read(tourStoreProvider).readJson(_draftKey);
      if (!mounted || _user != ref.read(currentUserIdProvider)) return;
      if (data != null && data['body'] is String) {
        _body.text = data['body'] as String;
        _fragment = data['fragment'] as String? ?? _fragment;
        _idempotency = data['idempotency'] as String? ?? _idempotency;
        _visit = DateTime.tryParse(data['visit'] as String? ?? '') ?? _visit;
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
    super.dispose();
  }

  String get _visitDate =>
      '${_visit.year}-${_visit.month.toString().padLeft(2, '0')}-${_visit.day.toString().padLeft(2, '0')}';
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
      'fragment': _fragment,
      'visit': _visitDate,
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
        noteNotice(context, '草稿已保存，仅自己可见');
      }
    } catch (_) {
      if (mounted) noteNotice(context, '草稿未能保存，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPhoto(int max) async {
    if (_picking || _photos.length >= max) return;
    setState(() => _picking = true);
    try {
      final path = await ref.read(notePhotoPickerProvider)();
      if (path == null ||
          !mounted ||
          _user != ref.read(currentUserIdProvider)) {
        return;
      }
      final root = await getApplicationSupportDirectory();
      final owner = sha256.convert(utf8.encode(_user ?? 'demo')).toString();
      final dir = Directory('${root.path}/community_drafts/$owner');
      await dir.create(recursive: true);
      final extension = path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final copied =
          await File(path).copy('${dir.path}/${const Uuid().v4()}.$extension');
      if (!mounted || _user != ref.read(currentUserIdProvider)) {
        await copied.delete();
        return;
      }
      setState(() {
        _photos.add(copied.path);
        _saved = false;
      });
    } catch (_) {
      if (mounted) noteNotice(context, '照片未能添加，请重试');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _publish(CommunityPolicy policy) async {
    if (_busy ||
        !policy.enabled ||
        _fragment == null ||
        _body.text.trim().isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _store();
      if (!mounted || _user != ref.read(currentUserIdProvider)) return;
      final repo = ref.read(experienceRepositoryProvider);
      await repo.shareCommunityPost(
          _fragment!,
          CommunityPostDraft(
              category: CommunityCategory.onSite,
              idempotencyKey: _idempotency,
              body: _body.text.trim(),
              photoPaths: List.of(_photos),
              visitedOn: _visitDate));
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
      context.go('/?tab=community');
      noteNotice(context, '见闻已发布');
    } catch (_) {
      if (mounted) noteNotice(context, '发布未成功，内容已保留，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
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
    return PopScope(
        canPop: !_busy,
        child: NoteScaffold(
            navigationEnabled: !_busy,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NoteTop('返回',
                  trailing: NoteButton(
                      label: '存草稿',
                      onTap: _busy || _loading ? null : _save,
                      child: SizedBox(
                          height: 44,
                          child: Center(
                              child: Text('存草稿',
                                  style: noteSans(12, color: noteRed)))))),
              Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: '留一则见闻'),
                    TextSpan(text: '。', style: noteSerif(34, color: noteRed))
                  ]),
                  style: noteSerif(34)),
              const SizedBox(height: 10),
              Text('把值得记住的，留在走过的地方。', style: noteSans(11, color: noteQuiet)),
              if (_loading)
                const Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(
                        strokeWidth: 1, color: noteQuiet))
              else ...[
                const SizedBox(height: 27),
                ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 170),
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
                Align(
                    alignment: Alignment.centerRight,
                    child: Text('${_body.text.characters.length} / $max',
                        style: noteItalic(11))),
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final path in _photos)
                    SizedBox(
                        width: 90,
                        height: 100,
                        child: Stack(children: [
                          ClipRRect(
                              borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(20)),
                              child: Image.file(File(path),
                                  width: 90, height: 100, fit: BoxFit.cover)),
                          Positioned(
                              right: 0,
                              bottom: 0,
                              child: ColoredBox(
                                  color: notePaper,
                                  child: NoteButton(
                                      label: '移除照片',
                                      onTap: _busy
                                          ? null
                                          : () => setState(() {
                                                _photos.remove(path);
                                                if (!_persistedPhotos
                                                    .contains(path)) {
                                                  _deletePhoto(path);
                                                }
                                                _saved = false;
                                              }),
                                      child: const SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: Center(
                                              child: DiscoveryIcon(
                                                  DiscoveryMark.close,
                                                  size: 17,
                                                  color: noteRed))))))
                        ])),
                  if (_photos.length < (policy?.maxMedia ?? 4))
                    NoteButton(
                        label: '添加照片',
                        onTap: _busy || _picking
                            ? null
                            : () => _pickPhoto(policy?.maxMedia ?? 4),
                        child: CustomPaint(
                            painter: const NoteDashedBorder(),
                            child: SizedBox(
                                width: 90,
                                height: 100,
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const DiscoveryIcon(DiscoveryMark.plus,
                                          size: 20, color: noteQuiet),
                                      const SizedBox(height: 9),
                                      Text(_picking ? '正在添加' : '添加照片',
                                          style: noteSans(11, color: noteQuiet))
                                    ]))))
                ]),
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
                                                      color: noteQuiet))
                                          ])),
                                      const SizedBox(width: 6),
                                      const DiscoveryIcon(
                                          DiscoveryMark.arrowRight,
                                          size: 14)
                                    ]))))),
                Padding(
                    padding: const EdgeInsets.fromLTRB(0, 6, 0, 17),
                    child: Text('选择这则见闻发生的地方，也可以回来后再写。',
                        style: noteSans(11, color: noteQuiet, height: 1.9))),
                if (placesState.hasError)
                  NoteFailure(
                      '地点暂时无法读取', () => ref.invalidate(notesPlacesProvider)),
                _row(
                    '到访日期',
                    NoteButton(
                        label: '选择到访日期',
                        onTap: _busy
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                    context: context,
                                    initialDate: _visit,
                                    firstDate: DateTime(2000),
                                    lastDate: ref.read(notesNowProvider)());
                                if (date != null && mounted) {
                                  setState(() {
                                    _visit = date;
                                    _saved = false;
                                  });
                                }
                              },
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(_visitDate.replaceAll('-', '/'),
                                style: noteSans(12))))),
                _row('谁可以看',
                    Text('公开 · 发布到见闻', style: noteSans(11, color: noteQuiet))),
                if (policyState.hasError)
                  NoteFailure(
                      '发布设置暂时无法读取', () => ref.invalidate(notesPolicyProvider)),
                if (policy?.enabled == false)
                  Text('见闻分享暂未开放', style: noteSans(12, color: noteQuiet)),
                const SizedBox(height: 28),
                Opacity(
                    opacity: !_busy &&
                            policy?.enabled == true &&
                            place != null &&
                            _body.text.trim().isNotEmpty
                        ? 1
                        : .4,
                    child: NoteButton(
                        key: const ValueKey('note-publish'),
                        label: '发布见闻',
                        onTap: _busy ||
                                policy == null ||
                                !policy.enabled ||
                                place == null ||
                                _body.text.trim().isEmpty
                            ? null
                            : () => _publish(policy),
                        child: Container(
                            height: 51,
                            decoration: const BoxDecoration(
                                border: Border.symmetric(
                                    horizontal: BorderSide(color: noteRed))),
                            child: Row(children: [
                              Text(_busy ? '正在发布' : '发布见闻',
                                  style: noteSerif(20, color: noteRed)),
                              const Spacer(),
                              const DiscoveryIcon(DiscoveryMark.arrowUpRight,
                                  size: 17, color: noteRed)
                            ])))),
                const SizedBox(height: 10),
                Text(_saved ? '草稿已保存，仅自己可见。' : '草稿仅自己可见，发布后旅人们才会看到。',
                    style: noteSans(11, color: noteQuiet)),
                const SizedBox(height: 24)
              ]
            ])));
  }

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
