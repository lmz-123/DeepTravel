import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/user_preferences_repository.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('preferences are user-scoped and survive repository recreation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final first = UserPreferencesRepository();

    await first.writePlaybackSpeed('user-a', 1.5);
    await first.writePlaybackSpeed('user-b', 0.8);
    await first.writeLocationMode('user-a', TourLocationMode.simulated);
    await first.writeLocationMode('user-b', TourLocationMode.real);
    await first.writeDownloadPolicy('user-a', DownloadPolicy.manual);
    await first.writeDownloadPolicy('user-b', DownloadPolicy.anyNetwork);
    await first.writeOrbPosition(
      'user-a',
      const NormalizedOrbPosition(0.2, 0.8),
    );
    await first.writeOrbPosition(
      'user-b',
      const NormalizedOrbPosition(0.9, 0.1),
    );

    final restored = UserPreferencesRepository();
    expect(await restored.readPlaybackSpeed('user-a'), 1.5);
    expect(await restored.readPlaybackSpeed('user-b'), 0.8);
    expect(
        await restored.readLocationMode('user-a'), TourLocationMode.simulated);
    expect(await restored.readLocationMode('user-b'), TourLocationMode.real);
    expect(await restored.readDownloadPolicy('user-a'), DownloadPolicy.manual);
    expect(
      await restored.readDownloadPolicy('user-b'),
      DownloadPolicy.anyNetwork,
    );
    expect((await restored.readOrbPosition('user-a')).x, 0.2);
    expect((await restored.readOrbPosition('user-b')).x, 0.9);
  });

  test('legacy global location mode migrates once to the first signed-in user',
      () async {
    SharedPreferences.setMockInitialValues({
      'tour_location_mode': TourLocationMode.simulated.name,
    });
    final repository = UserPreferencesRepository();

    expect(
      await repository.readLocationMode('user-a'),
      TourLocationMode.simulated,
    );
    expect(await repository.readLocationMode('user-b'), TourLocationMode.real);
    final values = (await SharedPreferences.getInstance()).getKeys();
    expect(values, isNot(contains('tour_location_mode')));
  });

  test('normalized orb position restores and clamps across layout changes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository = UserPreferencesRepository();
    await repository.writeOrbPosition(
      'user-a',
      const NormalizedOrbPosition(1.4, -0.3),
    );

    final restored =
        await UserPreferencesRepository().readOrbPosition('user-a');
    expect(restored.x, 1);
    expect(restored.y, 0);
    expect(
      restored.resolve(const Size(320, 600), const Size(64, 64)),
      const Offset(256, 0),
    );
    expect(
      restored.resolve(const Size(900, 1200), const Size(64, 64)),
      const Offset(836, 0),
    );
    expect(
      NormalizedOrbPosition.fromOffset(
        const Offset(-20, 900),
        const Size(320, 600),
        const Size(64, 64),
      ).clamped().y,
      1,
    );
  });
}
