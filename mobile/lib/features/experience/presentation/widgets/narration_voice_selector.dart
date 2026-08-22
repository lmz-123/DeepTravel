import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fragment_models.dart';

class NarrationVoiceSelector extends StatelessWidget {
  const NarrationVoiceSelector({
    required this.profiles,
    required this.selectedProfileId,
    required this.onSelected,
    this.dark = false,
    this.message,
    super.key,
  });

  final List<NarrationVoiceProfile> profiles;
  final String? selectedProfileId;
  final ValueChanged<String> onSelected;
  final bool dark;
  final String? message;

  NarrationVoiceProfile? get selected {
    for (final profile in profiles) {
      if (profile.id == selectedProfileId) return profile;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  @override
  Widget build(BuildContext context) {
    final active = selected;
    if (active == null) return const SizedBox.shrink();
    final foreground = dark ? AppColors.white : AppColors.ink;
    final secondary = foreground.withValues(alpha: .66);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Material(
        color:
            dark ? AppColors.white.withValues(alpha: .08) : AppColors.paperDeep,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: profiles.length > 1 ? () => _showPicker(context) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.graphic_eq_rounded, color: AppColors.gold),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('讲述音色 · ${active.name}',
                        style: TextStyle(
                            color: foreground, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      active.description.isEmpty
                          ? '整条路线将保持同一种讲述风格'
                          : active.description,
                      style: TextStyle(color: secondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (profiles.length > 1)
                Icon(Icons.tune_rounded, color: secondary, size: 21),
            ]),
          ),
        ),
      ),
      if (message != null) ...[
        const SizedBox(height: 7),
        Text(message!, style: TextStyle(color: secondary, fontSize: 11)),
      ],
    ]);
  }

  Future<void> _showPicker(BuildContext context) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('选择一路陪伴你的声音',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('文字内容完全相同，只改变讲述气质。',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(height: 16),
            ...profiles.map((profile) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: profile.id == selectedProfileId
                            ? AppColors.gold
                            : AppColors.ink.withValues(alpha: .12),
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.moss.withValues(alpha: .12),
                      child: const Icon(Icons.headphones_rounded,
                          color: AppColors.moss),
                    ),
                    title: Text(profile.name),
                    subtitle: Text(profile.description),
                    trailing: profile.id == selectedProfileId
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.moss)
                        : null,
                    onTap: () => Navigator.pop(context, profile.id),
                  ),
                )),
          ]),
        ),
      ),
    );
    if (chosen != null && chosen != selectedProfileId) onSelected(chosen);
  }
}
