// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Records code locations only. Error messages may contain signed URLs or paths.
List<String> diagnosticFrames(StackTrace stack) => stack
    .toString()
    .split('\n')
    .map(
      (line) => RegExp(
        r'^#\d+\s+([A-Za-z0-9_.$<>]+)\s+\(((?:package:[A-Za-z0-9_./:-]+|dart:[A-Za-z0-9_./:-]+))\)',
      ).firstMatch(line.trim()),
    )
    .whereType<RegExpMatch>()
    .take(16)
    .map((match) => '${match[1]}(${match[2]})')
    .toList();

class DiagnosticsService {
  const DiagnosticsService();
  static const channel = MethodChannel('musicon/app');
  static bool _installed = false;

  void install() {
    if (_installed) return;
    _installed = true;
    final flutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      unawaited(
        record('flutter', details.exception, details.stack ?? StackTrace.empty),
      );
      (flutterHandler ?? FlutterError.presentError)(details);
    };
    final platformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(record('dart', error, stack));
      // Preserve the existing failure behavior instead of hiding the exception.
      return platformHandler?.call(error, stack) ?? false;
    };
  }

  Future<void> record(String source, Object error, StackTrace stack) async {
    try {
      await channel.invokeMethod<void>('diagnosticsRecord', {
        'source': source,
        'type': error.runtimeType.toString(),
        'frames': diagnosticFrames(stack),
      });
    } catch (_) {
      /* Diagnostics must never interrupt playback or recurse. */
    }
  }

  Future<String> read() async {
    final report = await channel
        .invokeMethod<String>('diagnosticsRead')
        .timeout(const Duration(seconds: 10));
    if (report == null) throw StateError('Diagnóstico indisponível.');
    return report;
  }
}
