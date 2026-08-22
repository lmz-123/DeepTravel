import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fragment_models.dart';

class NarrationVoiceIconButton extends StatelessWidget {
  const NarrationVoiceIconButton({
    required this.profiles,
    required this.selectedProfileId,
    required this.onSelected,
    this.foregroundColor,
    super.key,
  });

  final List<NarrationVoiceProfile> profiles;
  final String? selectedProfileId;
  final ValueChanged<String> onSelected;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    if (profiles.length <= 1) return const SizedBox.shrink();
    final selected = profiles.firstWhere(
      (item) => item.id == selectedProfileId,
      orElse: () => profiles.first,
    );
    return IconButton(
      color: foregroundColor,
      tooltip: '讲述音色：${selected.name}',
      onPressed: () async {
        final chosen = await showNarrationVoicePicker(
          context,
          profiles: profiles,
          selectedProfileId: selectedProfileId,
        );
        if (chosen != null && chosen != selectedProfileId) onSelected(chosen);
      },
      icon: const Icon(Icons.record_voice_over_outlined),
    );
  }
}

Future<String?> showNarrationVoicePicker(
  BuildContext context, {
  required List<NarrationVoiceProfile> profiles,
  required String? selectedProfileId,
}) =>
    showModalBottomSheet<String>(
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
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('文字内容完全相同，只改变讲述气质。'),
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
