import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/presentation/atlas_gestures.dart';

void main() {
  testWidgets(
      'map owns vertical/diagonal drags and pinch; taps and outside scrolling survive',
      (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var movement = Offset.zero;
    var scale = 1.0;
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CustomScrollView(
      controller: scroll,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 50)),
        SliverToBoxAdapter(
            child: SizedBox(
                height: 300,
                child: AtlasGestureSurface(
                  key: const ValueKey('map'),
                  onStart: (_) {},
                  onUpdate: (d) {
                    movement += d.focalPointDelta;
                    scale = d.scale;
                  },
                  child: ColoredBox(
                      color: Colors.green,
                      child: Center(
                          child: GestureDetector(
                        onTap: () => taps++,
                        child: const SizedBox(
                            key: ValueKey('marker'),
                            width: 48,
                            height: 48,
                            child: ColoredBox(color: Colors.red)),
                      ))),
                ))),
        const SliverToBoxAdapter(child: SizedBox(height: 1200)),
      ],
    ))));
    final marker = tester.getCenter(find.byKey(const ValueKey('marker')));
    final tap = await tester.startGesture(marker);
    await tap.moveBy(const Offset(3, 2));
    await tap.up();
    await tester.pump();
    expect(taps, 1);
    for (final delta in [
      const Offset(0, -100),
      const Offset(0, 80),
      const Offset(60, -70),
      const Offset(100, 0)
    ]) {
      final before = movement;
      await tester.dragFrom(marker, delta);
      await tester.pumpAndSettle();
      expect(scroll.offset, 0, reason: 'Map gesture must not scroll the page');
      expect((movement - before).distance, greaterThan(30));
      expect(taps, 1, reason: 'A marker drag is not a tap');
    }
    final a =
        await tester.startGesture(marker - const Offset(25, 0), pointer: 1);
    final b =
        await tester.startGesture(marker + const Offset(25, 0), pointer: 2);
    await a.moveBy(const Offset(-60, 0));
    await b.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(scale, greaterThan(1.5));
    expect(scroll.offset, 0);
    await a.cancel();
    await b.cancel();
    await tester.pump();
    await tester.dragFrom(const Offset(100, 450), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(80));
  });
}
