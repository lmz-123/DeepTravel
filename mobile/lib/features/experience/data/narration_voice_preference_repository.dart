import 'package:shared_preferences/shared_preferences.dart';

class NarrationVoicePreferenceKey {
  const NarrationVoicePreferenceKey({
    required this.userId,
    required this.routeId,
  });

  final String userId;
  final String routeId;

  @override
  bool operator ==(Object other) =>
      other is NarrationVoicePreferenceKey &&
      other.userId == userId &&
      other.routeId == routeId;

  @override
  int get hashCode => Object.hash(userId, routeId);
}

class NarrationVoicePreferenceRepository {
  static const _prefix = 'narration_voice';

  String _key(NarrationVoicePreferenceKey key) =>
      '$_prefix:${key.userId}:${key.routeId}';

  Future<String?> read(NarrationVoicePreferenceKey key) async =>
      (await SharedPreferences.getInstance()).getString(_key(key));

  Future<void> write(NarrationVoicePreferenceKey key, String profileId) async {
    await (await SharedPreferences.getInstance())
        .setString(_key(key), profileId);
  }
}
