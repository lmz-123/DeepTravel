import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A map pan must win before the enclosing page's vertical drag. Scale's
/// default pan slop is larger than a Scrollable's drag slop, so the page can
/// otherwise steal single-finger drags. Keep a small slop for marker taps.
class AtlasScaleGestureRecognizer extends ScaleGestureRecognizer {
  final _origins = <int, Offset>{};
  @override
  void addAllowedPointer(PointerDownEvent event) {
    _origins[event.pointer] = event.position;
    super.addAllowedPointer(event);
    if (_origins.length > 1) resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    final origin = _origins[event.pointer];
    if (event is PointerMoveEvent &&
        origin != null &&
        (event.position - origin).distance > 8) {
      resolve(GestureDisposition.accepted);
    }
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _origins.remove(event.pointer);
    }
  }

  @override
  void dispose() {
    _origins.clear();
    super.dispose();
  }
}

class AtlasGestureSurface extends StatelessWidget {
  const AtlasGestureSurface(
      {super.key,
      required this.onStart,
      required this.onUpdate,
      required this.child});
  final GestureScaleStartCallback onStart;
  final GestureScaleUpdateCallback onUpdate;
  final Widget child;
  @override
  Widget build(BuildContext context) => RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          AtlasScaleGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<AtlasScaleGestureRecognizer>(
            AtlasScaleGestureRecognizer.new,
            (recognizer) => recognizer
              ..onStart = onStart
              ..onUpdate = onUpdate,
          ),
        },
        child: RepaintBoundary(child: child),
      );
}
