import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void popOrGo(BuildContext context, String fallbackLocation) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    GoRouter.maybeOf(context)?.go(fallbackLocation);
  }
}

class RouteBackScope extends StatelessWidget {
  const RouteBackScope({
    required this.fallbackLocation,
    required this.child,
    super.key,
  });

  final String fallbackLocation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) GoRouter.maybeOf(context)?.go(fallbackLocation);
      },
      child: child,
    );
  }
}
