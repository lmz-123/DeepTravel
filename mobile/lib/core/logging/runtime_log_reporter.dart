import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';

final runtimeLogReporterProvider = Provider<RuntimeLogReporter?>((ref) => null);

class RuntimeLogReporter {
  RuntimeLogReporter._(this._preferences, this._client, this._sessionId);

  static const _queueKey = 'runtime_log_queue_v1';
  static const _sessionKey = 'runtime_log_session_v1';
  static const _maxQueueSize = 120;
  static const _batchSize = 30;

  final SharedPreferences _preferences;
  final Dio _client;
  final String _sessionId;
  bool _flushing = false;
  Future<void> _queueLock = Future.value();

  static Future<RuntimeLogReporter> create({Dio? client}) async {
    final preferences = await SharedPreferences.getInstance();
    var sessionId = preferences.getString(_sessionKey);
    if (sessionId == null) {
      sessionId = const Uuid().v4();
      await preferences.setString(_sessionKey, sessionId);
    }
    return RuntimeLogReporter._(
      preferences,
      client ??
          Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          )),
      sessionId,
    );
  }

  Future<void> info(String category, String message,
          {Map<String, Object?> context = const {}}) =>
      record('info', category, message, context: context);

  Future<void> warning(String category, String message,
          {Map<String, Object?> context = const {}}) =>
      record('warning', category, message, context: context);

  Future<void> error(String category, String message,
          {Object? error,
          StackTrace? stackTrace,
          Map<String, Object?> context = const {}}) =>
      record(
        'error',
        category,
        message,
        context: {
          ...context,
          if (error != null) 'error_type': error.runtimeType.toString(),
          if (stackTrace != null) 'stack': _boundedStack(stackTrace.toString()),
        },
      );

  Future<void> record(
    String level,
    String category,
    String message, {
    Map<String, Object?> context = const {},
  }) async {
    if (AppConfig.runtimeLogEndpoint.isEmpty ||
        AppConfig.runtimeLogToken.isEmpty) {
      return;
    }
    final event = <String, dynamic>{
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'category': category,
      'message': message,
      'session_id': _sessionId,
      'app_version': AppConfig.appVersion,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'source': 'deeptravel-flutter',
      'context': _safeContext(context),
    };
    await _withQueueLock(() async {
      final queue = await _readQueue();
      queue.add(event);
      await _writeQueue(boundRuntimeLogQueue(queue, _maxQueueSize));
    });
    unawaited(flush());
  }

  Future<void> flush() async {
    if (_flushing ||
        AppConfig.runtimeLogEndpoint.isEmpty ||
        AppConfig.runtimeLogToken.isEmpty) {
      return;
    }
    _flushing = true;
    try {
      while (true) {
        final queue = await _withQueueLock(_readQueue);
        if (queue.isEmpty) return;
        final batch = queue.take(_batchSize).toList();
        await _client.post<void>(
          AppConfig.runtimeLogEndpoint,
          data: {'events': batch},
          options: Options(headers: {
            'X-Client-Log-Token': AppConfig.runtimeLogToken,
            Headers.contentTypeHeader: Headers.jsonContentType,
          }),
        );
        await _withQueueLock(() async {
          final latest = await _readQueue();
          await _writeQueue(latest.skip(batch.length).toList());
        });
      }
    } on DioException {
      // The bounded queue stays on-device and is retried by the next event/start.
    } finally {
      _flushing = false;
    }
  }

  Future<List<Map<String, dynamic>>> _readQueue() async {
    final raw = _preferences.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on FormatException {
      await _preferences.remove(_queueKey);
      return [];
    }
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    await _preferences.setString(_queueKey, jsonEncode(queue));
  }

  Future<T> _withQueueLock<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _queueLock;
    _queueLock = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }

  static String _boundedStack(String value) =>
      value.length <= 1800 ? value : value.substring(0, 1800);

  static Map<String, Object?> _safeContext(Map<String, Object?> context) {
    const forbidden = {
      'authorization',
      'cookie',
      'password',
      'token',
      'photo',
      'latitude',
      'longitude',
    };
    return {
      for (final entry in context.entries)
        if (!forbidden.contains(entry.key.toLowerCase()))
          entry.key: _safeValue(entry.value),
    };
  }

  static Object? _safeValue(Object? value) {
    if (value == null || value is num || value is bool) return value;
    final text = value.toString();
    return text.length <= 500 ? text : text.substring(0, 500);
  }
}

List<Map<String, dynamic>> boundRuntimeLogQueue(
    List<Map<String, dynamic>> queue, int limit) {
  if (queue.length <= limit) return List<Map<String, dynamic>>.from(queue);
  return queue.sublist(queue.length - limit);
}
