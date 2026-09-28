import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../active_tour_controller.dart';
import '../experience_providers.dart';

class ManualReadingSession {
  const ManualReadingSession({
    this.currentId,
    this.visited = const {},
    this.positions = const {},
  });
  final String? currentId;
  final Set<String> visited;
  final Map<String, Duration> positions;
}

/// Manual listening progress never changes a location-based journey ledger.
class ManualSessionController extends AsyncNotifier<ManualReadingSession> {
  ManualSessionController(this.routeId);
  final String routeId;
  String? _key;

  @override
  Future<ManualReadingSession> build() async {
    final userId = ref.watch(currentUserIdProvider);
    // Account scope prevents another traveler inheriting this reader's history.
    _key = userId == null ? null : 'manual_reader:$userId:$routeId';
    if (_key == null) return const ManualReadingSession();
    Map<String, dynamic>? value;
    try {
      value = await ref.read(tourStoreProvider).readJson(_key!);
    } catch (_) {
      return const ManualReadingSession();
    }
    if (value == null) return const ManualReadingSession();
    return ManualReadingSession(
      currentId: value['current_id'] as String?,
      visited: Set<String>.from(value['visited'] as List? ?? const []),
      positions: (value['positions'] as Map? ?? const {}).map(
        (key, value) => MapEntry(
          key.toString(),
          Duration(milliseconds: (value as num).round()),
        ),
      ),
    );
  }

  Future<void> remember(
    String chapterId, {
    Duration? position,
    bool opened = false,
  }) async {
    final key = _key;
    final current = state.asData?.value ?? await future;
    if (_key != key) return;
    final next = ManualReadingSession(
      currentId: opened ? chapterId : current.currentId,
      visited: opened ? {...current.visited, chapterId} : current.visited,
      positions: position == null
          ? current.positions
          : {...current.positions, chapterId: position},
    );
    state = AsyncData(next);
    if (key != null) {
      try {
        await ref.read(tourStoreProvider).saveJson(key, {
          'current_id': next.currentId,
          'visited': next.visited.toList(),
          'positions': next.positions.map(
            (key, value) => MapEntry(key, value.inMilliseconds),
          ),
        });
      } catch (_) {
        /* Reading remains available if persistence is temporarily unavailable. */
      }
    }
  }
}

final manualSessionProvider = AsyncNotifierProvider.family<
    ManualSessionController,
    ManualReadingSession,
    String>(ManualSessionController.new);
