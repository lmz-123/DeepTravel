import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/travel_destinations.dart';
import '../../domain/community_models.dart';
import '../experience_providers.dart';
import '../active_tour_controller.dart';
import '../widgets/discovery_art.dart';
import '../widgets/traveler_bottom_navigation.dart';

const notePaper = Color(0xfff5f0e7);
const noteInk = Color(0xff30372d);
const noteRed = Color(0xffc84832);
const noteQuiet = Color(0xff807664);
const noteLine = Color(0xffd7d2c5);
TextStyle noteSerif(double size,
        {Color color = noteInk,
        double height = 1.5,
        FontWeight weight = FontWeight.w400}) =>
    discoverySerif(size, color: color, height: height, weight: weight);
TextStyle noteSans(double size, {Color color = noteInk, double height = 1.6}) =>
    discoverySans(size, color: color, height: height)
        .copyWith(fontFamily: 'Noto Sans SC');
TextStyle noteItalic(double size, {Color color = noteQuiet}) => TextStyle(
    fontFamily: 'Georgia',
    fontSize: size,
    fontStyle: FontStyle.italic,
    color: color,
    height: 1.5);
double noteInset(BuildContext context) =>
    MediaQuery.sizeOf(context).width <= 360 ? 19 : 23;
String noteTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.month} 月 ${local.day} 日 · ${two(local.hour)}:${two(local.minute)}';
}

void noteNotice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message, style: noteSans(12, color: notePaper)),
          backgroundColor: noteInk));

class NoteButton extends StatelessWidget {
  const NoteButton(
      {super.key,
      required this.label,
      required this.child,
      this.onTap,
      this.selected});
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool? selected;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: label,
      selected: selected,
      enabled: onTap != null,
      child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          hoverColor: noteRed.withValues(alpha: .035),
          highlightColor: noteRed.withValues(alpha: .035),
          child: child));
}

class NoteArrow extends StatelessWidget {
  const NoteArrow(this.text,
      {super.key,
      this.onTap,
      this.size = 15,
      this.icon = DiscoveryMark.arrowUpRight,
      this.underline = true,
      this.leadingIcon = false});
  final String text;
  final VoidCallback? onTap;
  final double size;
  final DiscoveryMark icon;
  final bool underline, leadingIcon;
  @override
  Widget build(BuildContext context) => NoteButton(
      label: text,
      onTap: onTap,
      child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
              border: underline
                  ? Border(
                      bottom: BorderSide(color: noteRed.withValues(alpha: .5)))
                  : null),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (leadingIcon) ...[
              DiscoveryIcon(icon, size: 17, color: noteRed),
              const SizedBox(width: 7),
            ],
            Text(text,
                style: noteSerif(size,
                    color: onTap == null ? noteQuiet : noteRed)),
            if (!leadingIcon) ...[
              const SizedBox(width: 8),
              DiscoveryIcon(icon,
                  size: 17, color: onTap == null ? noteQuiet : noteRed)
            ]
          ])));
}

class NoteScaffold extends StatelessWidget {
  const NoteScaffold(
      {super.key,
      required this.child,
      this.scrollController,
      this.navigationEnabled = true});
  final Widget child;
  final ScrollController? scrollController;
  final bool navigationEnabled;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: notePaper,
      bottomNavigationBar: AbsorbPointer(
          absorbing: !navigationEnabled,
          child: const SafeArea(
              top: false,
              bottom: false,
              child: TravelerBottomNavigation(
                  active: TravelerSection.community, editorial: true))),
      body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.symmetric(horizontal: noteInset(context)),
              child: child)));
}

class NoteTop extends StatelessWidget {
  const NoteTop(this.label, {super.key, this.trailing});
  final String label;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
      height: 68,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: noteLine))),
      child: Row(children: [
        Expanded(
            child: NoteButton(
                label: '返回',
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.go('/?tab=community'),
                child: SizedBox(
                    height: 44,
                    child: Row(children: [
                      const DiscoveryIcon(DiscoveryMark.arrowLeft,
                          size: 17, color: noteQuiet),
                      const SizedBox(width: 8),
                      Text(label, style: noteSans(12, color: noteQuiet))
                    ])))),
        if (trailing != null) trailing!
      ]));
}

class NoteAuthor extends StatelessWidget {
  const NoteAuthor(this.post, {super.key});
  final CommunityPost post;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: SizedBox(
          height: 36,
          child: Row(children: [
            NoteAvatar(post.author.displayName),
            const SizedBox(width: 9),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(post.author.displayName, style: noteSans(12)),
                  Text(noteTime(post.createdAt),
                      style: noteSans(10, color: noteQuiet))
                ])
          ])));
}

class NoteAvatar extends StatelessWidget {
  const NoteAvatar(this.name, {super.key, this.sand = false});
  final String name;
  final bool sand;
  @override
  Widget build(BuildContext context) => Container(
      width: 29,
      height: 29,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: sand ? const Color(0xffe8decd) : const Color(0xffe0e5cd)),
      child: Text(
          name.isEmpty
              ? '旅'
              : (name.startsWith('阿') || name.startsWith('小')) &&
                      name.characters.length > 1
                  ? name.characters.elementAt(1)
                  : name.characters.first,
          style: noteSerif(15)));
}

class NotePhoto extends ConsumerStatefulWidget {
  const NotePhoto(this.post, {super.key, this.height = 249, this.onTap});
  final CommunityPost post;
  final double height;
  final VoidCallback? onTap;
  @override
  ConsumerState<NotePhoto> createState() => _NotePhotoState();
}

class _NotePhotoState extends ConsumerState<NotePhoto> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final userId = ref.watch(currentUserIdProvider) ?? 'demo';
    if (post.media.isEmpty) return const SizedBox.shrink();
    return SizedBox(
        height: widget.height,
        child: Stack(children: [
          ClipRRect(
              borderRadius:
                  const BorderRadius.only(topRight: Radius.circular(42)),
              child: PageView.builder(
                  itemCount: post.media.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, index) {
                    final media = post.media[index];
                    final bytes = ref.watch(communityMediaBytesProvider(
                        CommunityMediaKey(userId, media)));
                    return NoteButton(
                        label: '查看动态照片',
                        onTap: widget.onTap,
                        child: bytes.when(
                            data: (data) => Image.memory(data,
                                width: double.infinity,
                                height: widget.height,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, __, ___) =>
                                    _photoError(media, userId)),
                            loading: () => const ColoredBox(
                                color: Color(0xffe8e6d8),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1, color: noteQuiet))),
                            error: (_, __) => _photoError(media, userId)));
                  })),
          Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                  padding: const EdgeInsets.fromLTRB(0, 9, 15, 0),
                  decoration: const BoxDecoration(
                      color: notePaper,
                      borderRadius:
                          BorderRadius.only(topRight: Radius.circular(16))),
                  child: Text(
                      post.place?.theme.contains('海') == true
                          ? '海边 / COAST'
                          : '街巷 / STREETS',
                      style: noteItalic(11)))),
          if (post.media.length > 1)
            Positioned(
                right: 12,
                bottom: 10,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: notePaper,
                    child: Text('${_index + 1} / ${post.media.length}',
                        style: noteItalic(11))))
        ]));
  }

  Widget _photoError(CommunityMedia media, String user) => ColoredBox(
      color: const Color(0xffe8e6d8),
      child: Center(
          child: TextButton(
              onPressed: () => ref.invalidate(
                  communityMediaBytesProvider(CommunityMediaKey(user, media))),
              child: Text('重新加载照片', style: noteSans(12)))));
}

class NotePlaceRow extends ConsumerWidget {
  const NotePlaceRow(this.post, {super.key, this.detail = false, this.onOpen});
  final CommunityPost post;
  final bool detail;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = post.place;
    if (place == null) return const SizedBox.shrink();
    final info = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
          padding: EdgeInsets.only(top: 3),
          child: DiscoveryIcon(DiscoveryMark.pin, size: 13, color: noteQuiet)),
      const SizedBox(width: 7),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${place.cityName} · ${place.routeTitle}',
            style: detail
                ? noteSerif(18, height: 1.6)
                : noteSans(12, height: 1.7)),
        const SizedBox(height: 2),
        Text(place.name, style: noteSans(11, color: noteQuiet, height: 1.8))
      ]))
    ]);
    return Container(
        margin: EdgeInsets.fromLTRB(0, detail ? 21 : 14, 0, detail ? 7 : 8),
        padding: EdgeInsets.symmetric(vertical: detail ? 18 : 7),
        decoration: detail
            ? const BoxDecoration(
                border:
                    Border.symmetric(horizontal: BorderSide(color: noteLine)))
            : null,
        child: Row(children: [
          Expanded(
              child: detail
                  ? info
                  : NoteButton(label: '查看动态详情', onTap: onOpen, child: info)),
          const SizedBox(width: 14),
          NoteArrow('去随行', size: detail ? 17 : 15, onTap: () async {
            final tour = ref.read(activeTourControllerProvider);
            if (tour.session != null &&
                tour.status != 'idle' &&
                tour.status != 'stopped' &&
                tour.route?.slug != place.routeSlug) {
              final change = await showDialog<bool>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                          backgroundColor: notePaper,
                          title: Text('前往新的地点？', style: noteSerif(23)),
                          content: Text('将结束当前随行，前往${place.routeTitle}。',
                              style: noteSans(13)),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(dialog, false),
                                child: const Text('继续当前随行')),
                            TextButton(
                                onPressed: () => Navigator.pop(dialog, true),
                                child: const Text('前往')),
                          ]));
              if (change != true || !context.mounted) return;
              try {
                await ref
                    .read(activeTourControllerProvider.notifier)
                    .stopTour();
              } catch (_) {
                if (context.mounted) noteNotice(context, '当前随行未能结束，请重试');
                return;
              }
            }
            if (context.mounted) {
              context.go(companionLocation(place.routeSlug,
                  fragmentId: place.fragmentId, requestSelection: true));
            }
          })
        ]));
  }
}

class NoteActions extends StatelessWidget {
  const NoteActions(this.post,
      {super.key, this.onLike, this.onComments, this.onSave});
  final CommunityPost post;
  final VoidCallback? onLike, onComments, onSave;
  Widget _action(String label, DiscoveryMark icon, VoidCallback? tap,
          {bool selected = false}) =>
      NoteButton(
          label: label,
          selected: selected,
          onTap: tap,
          child: SizedBox(
              height: 36,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                DiscoveryIcon(icon,
                    size: 17,
                    color: selected ? noteRed : noteQuiet,
                    filled: selected),
                const SizedBox(width: 7),
                Text(label,
                    style: noteSans(11, color: selected ? noteRed : noteQuiet))
              ])));
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 12),
      child: Row(children: [
        SizedBox(
            width: 44,
            child: _action('${post.likeCount}', DiscoveryMark.heart, onLike,
                selected: post.viewerHasLiked)),
        const SizedBox(width: 21),
        SizedBox(
            width: 44,
            child: _action(
                '${post.commentCount}', DiscoveryMark.comment, onComments)),
        const Spacer(),
        _action(
            post.viewerHasSaved ? '已收藏' : '收藏', DiscoveryMark.bookmark, onSave,
            selected: post.viewerHasSaved)
      ]));
}

class NoteFailure extends StatelessWidget {
  const NoteFailure(this.message, this.retry, {super.key});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Text(message, style: noteSans(13, color: noteQuiet)),
        const SizedBox(height: 14),
        NoteArrow('重新加载', onTap: retry)
      ]));
}

class NoteDashedBorder extends CustomPainter {
  const NoteDashedBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffbbb6a7)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRect(Rect.fromLTWH(.5, .5, size.width - 1, size.height - 1));
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 7) {
        canvas.drawPath(metric.extractPath(offset, offset + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(NoteDashedBorder oldDelegate) => false;
}
