import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/presentation/widgets/evidence_photo_widgets.dart';

void main() {
  for (final size in const [Size(320, 568), Size(430, 932)]) {
    testWidgets('keeps image ratio and stable worn frame at ${size.width}px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NostalgicPhotoFrame(
              key: ValueKey('keepsake-frame'),
              width: 180,
              child: ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ));
      await tester.pump();

      final frame = find.byKey(const ValueKey('keepsake-frame'));
      expect(tester.getSize(frame).width, 180);
      expect(tester.getSize(frame).height, closeTo(158, .1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion removes keepsake tilt', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Center(
          child: NostalgicPhotoFrame(
            key: ValueKey('reduced-frame'),
            width: 180,
            child: ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    ));
    final transform = tester.widget<Transform>(find.descendant(
      of: find.byKey(const ValueKey('reduced-frame')),
      matching: find.byType(Transform),
    ));
    expect(transform.transform.isIdentity(), isTrue);
  });
}
