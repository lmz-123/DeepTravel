import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../experience_providers.dart';
import 'discovery_art.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    required this.kind,
    required this.targetId,
    this.color,
    this.mark,
    this.filledWhenSelected = false,
    super.key,
  });

  final String kind;
  final String targetId;
  final Color? color;
  final DiscoveryMark? mark;
  final bool filledWhenSelected;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final selected = userId != null &&
        (ref.watch(travelerFavoritesProvider(userId)).value?.any(
                  (item) =>
                      item.kind == widget.kind &&
                      item.targetId == widget.targetId,
                ) ??
            false);
    return IconButton(
      tooltip: selected ? '移出书架' : '放入书架',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: _busy ? null : () => _toggle(userId, selected),
      color: selected && widget.filledWhenSelected
          ? const Color(0xFFF5F0E7)
          : widget.color,
      style: selected && widget.filledWhenSelected
          ? IconButton.styleFrom(backgroundColor: const Color(0xFF252824))
          : null,
      icon: widget.mark != null
          ? DiscoveryIcon(widget.mark!,
              size: 20,
              filled: selected,
              color: selected
                  ? const Color(0xffc84832)
                  : widget.color ?? const Color(0xff30372d))
          : Icon(
              selected
                  ? widget.filledWhenSelected
                      ? Icons.check_rounded
                      : Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            ),
    );
  }

  Future<void> _toggle(String? userId, bool selected) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录后可以收藏城市、景点和主题')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final repository = ref.read(experienceRepositoryProvider);
      if (selected) {
        await repository.removeFavorite(widget.kind, widget.targetId);
      } else {
        await repository.addFavorite(widget.kind, widget.targetId);
      }
      ref.invalidate(travelerFavoritesProvider(userId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('收藏状态暂时无法更新，请稍后重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
