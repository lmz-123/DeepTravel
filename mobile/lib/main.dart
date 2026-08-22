import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'core/logging/runtime_log_reporter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final reporter = await RuntimeLogReporter.create();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(reporter.error(
      details.library ?? 'flutter',
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
      context: {'context': details.context?.toDescription() ?? ''},
    ));
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(reporter.error('uncaught_async', error.toString(),
        error: error, stackTrace: stackTrace));
    return true;
  };
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.jiandi.jiandi.narration',
      androidNotificationChannelName: '见地行走故事',
      androidNotificationOngoing: true,
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'background audio startup',
      context: ErrorDescription('initializing Android background narration'),
    ));
  }
  unawaited(reporter.info('lifecycle', 'application_started'));
  runApp(ProviderScope(
    overrides: [runtimeLogReporterProvider.overrideWithValue(reporter)],
    child: const JiandiApp(),
  ));
}
