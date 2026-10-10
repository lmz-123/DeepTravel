import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/community_models.dart';
import '../widgets/discovery_art.dart';
import 'notes_controller.dart';
import 'notes_widgets.dart';

class NotesFilterBar extends ConsumerStatefulWidget {
  const NotesFilterBar({super.key});
  @override
  ConsumerState<NotesFilterBar> createState() => _NotesFilterBarState();
}

class _NotesFilterBarState extends ConsumerState<NotesFilterBar> {
  int? _tab;
  int _cityPage = 0;
  String _search = '';
  void _update(
      {CommunityCategory? category,
      double? radius,
      String? order,
      bool clearCategory = false,
      bool clearRadius = false}) {
    final current = ref.read(notesFiltersProvider);
    ref.read(notesFiltersProvider.notifier).select(CommunityQuery(
        category: clearCategory ? null : category ?? current.category,
        radiusKm: clearRadius ? null : radius ?? current.radiusKm,
        order: order ?? current.order));
  }

  Widget _choice(String label, bool selected, VoidCallback? tap) => NoteButton(
      label: label,
      selected: selected,
      onTap: tap,
      child: SizedBox(
          height: 44,
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: noteSerif(15,
                        color: tap == null
                            ? noteLine
                            : selected
                                ? noteRed
                                : noteInk))),
            if (selected)
              const DiscoveryIcon(DiscoveryMark.check, size: 13, color: noteRed)
          ])));
  @override
  Widget build(BuildContext context) {
    final city = ref.watch(notesCityProvider),
        filters = ref.watch(notesFiltersProvider);
    final places = ref.watch(notesPlacesProvider);
    final cities = {
      for (final p in places.value ?? <CommunityPlace>[]) p.citySlug: p.cityName
    };
    final location = ref.watch(notesLocationProvider);
    final located = location.value != null;
    final feed = ref.watch(notesFeedProvider);
    final labels = [
      cities[city] ?? '全部城市',
      filters.category?.label ?? '全部类型',
      filters.radiusKm == null ? '距离' : '${filters.radiusKm!.round()} km 内',
      filters.order == 'nearest' ? '离我最近' : '最新发布'
    ];
    final entries = cities.entries
        .where((e) =>
            e.value.contains(_search) ||
            e.key.toLowerCase().contains(_search.toLowerCase()))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final pages = (entries.length / 6).ceil().clamp(1, 100000);
    final page = _cityPage.clamp(0, pages - 1);
    final changed = city != null ||
        filters.category != null ||
        filters.radiusKm != null ||
        filters.order != 'latest';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          decoration: const BoxDecoration(
              border:
                  Border.symmetric(horizontal: BorderSide(color: noteLine))),
          child: Row(children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                  child: NoteButton(
                      key: ValueKey('notes-filter-$i'),
                      label: labels[i],
                      onTap: () => setState(() => _tab = _tab == i ? null : i),
                      child: Container(
                          height: 49,
                          padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
                          decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: _tab == i
                                          ? noteRed
                                          : Colors.transparent,
                                      width: 2))),
                          child: Row(children: [
                            Expanded(
                                child: Text(labels[i],
                                    style: noteSans(
                                        MediaQuery.sizeOf(context).width <= 360
                                            ? 11
                                            : 12,
                                        color: _tab == i ? noteRed : noteInk),
                                    maxLines: 1)),
                            Icon(
                                _tab == i
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 13,
                                color: noteQuiet)
                          ]))))
          ])),
      if (_tab != null)
        Container(
            padding: const EdgeInsets.only(top: 7, bottom: 10),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: noteLine))),
            child: Column(children: [
              if (_tab == 0) ...[
                TextField(
                    onChanged: (value) => setState(() {
                          _search = value;
                          _cityPage = 0;
                        }),
                    style: noteSans(16),
                    decoration: InputDecoration(
                        hintText: '搜索城市 / 拼音',
                        prefixIcon: const Icon(Icons.search, size: 17),
                        filled: false,
                        border: const UnderlineInputBorder(
                            borderSide: BorderSide(color: noteLine)))),
                _choice('全部城市', city == null,
                    () => ref.read(notesCityProvider.notifier).select(null)),
                if (places.hasError)
                  NoteFailure(
                      '城市暂时无法读取', () => ref.invalidate(notesPlacesProvider)),
                if (places.isLoading)
                  const LinearProgressIndicator(minHeight: 1, color: noteRed),
                ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 88),
                    child: LayoutBuilder(
                        builder: (context, box) => Wrap(spacing: 13, children: [
                              for (final entry
                                  in entries.skip(page * 6).take(6))
                                SizedBox(
                                    width: (box.maxWidth - 26) / 3,
                                    child: _choice(
                                        entry.value,
                                        city == entry.key,
                                        () => ref
                                            .read(notesCityProvider.notifier)
                                            .select(entry.key)))
                            ]))),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  IconButton(
                      tooltip: '上一页城市',
                      onPressed: page > 0
                          ? () => setState(() => _cityPage = page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left, size: 18)),
                  Text('${page + 1} / $pages', style: noteItalic(11)),
                  IconButton(
                      tooltip: '下一页城市',
                      onPressed: page + 1 < pages
                          ? () => setState(() => _cityPage = page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right, size: 18))
                ]),
              ] else
                LayoutBuilder(builder: (context, box) {
                  final choices = <Widget>[
                    if (_tab == 1) ...[
                      _choice('全部类型', filters.category == null,
                          () => _update(clearCategory: true)),
                      for (final c in [
                        CommunityCategory.viewpoint,
                        CommunityCategory.onSite,
                        CommunityCategory.experience
                      ])
                        _choice(c.label, filters.category == c,
                            () => _update(category: c))
                    ],
                    if (_tab == 2) ...[
                      _choice('不限距离', filters.radiusKm == null,
                          () => _update(clearRadius: true)),
                      for (final km in [5, 20, 50, 100])
                        _choice(
                            '$km km 内',
                            filters.radiusKm == km,
                            located
                                ? () => _update(radius: km.toDouble())
                                : null)
                    ],
                    if (_tab == 3) ...[
                      _choice('最新发布', filters.order == 'latest',
                          () => _update(order: 'latest')),
                      _choice('离我最近', filters.order == 'nearest',
                          located ? () => _update(order: 'nearest') : null)
                    ],
                  ];
                  return Wrap(spacing: 20, children: [
                    for (final choice in choices)
                      SizedBox(width: (box.maxWidth - 20) / 2, child: choice)
                  ]);
                }),
              if (!located && (_tab == 2 || _tab == 3))
                Align(
                    alignment: Alignment.centerLeft,
                    child: NoteArrow(location.isLoading ? '正在定位' : '开启定位',
                        size: 12,
                        onTap: location.isLoading
                            ? null
                            : () => ref
                                .read(notesLocationProvider.notifier)
                                .locate())),
            ])),
      SizedBox(
          height: 44,
          child: Row(children: [
            Expanded(
                child: Text(
                    feed.isLoading
                        ? '正在寻找见闻…'
                        : feed.hasError
                            ? '暂未载入'
                            : '${feed.value?.total ?? feed.value?.items.length ?? 0}${feed.value?.total == null && feed.value?.hasMore == true ? '+' : ''} 则见闻',
                    style: noteSans(11, color: noteQuiet))),
            if (changed)
              NoteButton(
                  label: '重置筛选',
                  onTap: () {
                    ref.read(notesCityProvider.notifier).select(null);
                    ref
                        .read(notesFiltersProvider.notifier)
                        .select(const CommunityQuery());
                  },
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('重置', style: noteSans(11, color: noteRed)))),
            if (_tab != null)
              NoteButton(
                  label: '收起筛选',
                  onTap: () => setState(() => _tab = null),
                  child: Text('收起 ↑', style: noteSans(11, color: noteQuiet)))
          ])),
      if (!located)
        NoteArrow(
            location.isLoading
                ? '正在定位'
                : location.hasError
                    ? '定位未成功，重试'
                    : '开启定位，看看离你多远',
            size: 11,
            underline: false,
            onTap: location.isLoading
                ? null
                : () => ref.read(notesLocationProvider.notifier).locate()),
      const SizedBox(height: 15),
    ]);
  }
}
