import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android declares the background narration service and permissions', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android.permission.WAKE_LOCK'));
    expect(manifest,
        contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'));
    expect(manifest, contains('com.ryanheise.audioservice.AudioService'));
    expect(
        manifest, contains('com.ryanheise.audioservice.MediaButtonReceiver'));
    expect(manifest, contains('android:foregroundServiceType="mediaPlayback"'));
  });

  test('MainActivity provides the audio service Flutter engine', () {
    final activity =
        File('android/app/src/main/kotlin/com/jiandi/jiandi/MainActivity.kt')
            .readAsStringSync();

    expect(activity, contains('AudioServiceActivity'));
    expect(activity, contains('MainActivity : AudioServiceActivity()'));
  });
}
