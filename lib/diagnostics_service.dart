// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  static bool _desktop = false;
  static Future<void> _tail = Future.value();

  void install({bool desktop = false}) {
    _desktop = desktop;
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
      if (_desktop) {
        _tail = _tail
            .then((_) async {
              final file = File(
                p.join(
                  (await getApplicationSupportDirectory()).path,
                  'diagnostics.json',
                ),
              );
              List<dynamic> events = [];
              try {
                if (await file.exists()) {
                  events = jsonDecode(await file.readAsString()) as List;
                }
              } catch (_) {
                /* Recover a partial log. */
              }
              events.add({
                'time': DateTime.now().millisecondsSinceEpoch,
                'source': source,
                'type': error.runtimeType.toString(),
                'frames': diagnosticFrames(stack),
              });
              if (events.length > 8) events = events.sublist(events.length - 8);
              await file.parent.create(recursive: true);
              await file.writeAsString(jsonEncode(events), flush: true);
            })
            .catchError((Object _) {});
        await _tail;
        return;
      }
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
    if (_desktop) {
      await _tail;
      final info = await PackageInfo.fromPlatform();
      final file = File(
        p.join(
          (await getApplicationSupportDirectory()).path,
          'diagnostics.json',
        ),
      );
      List<dynamic> events = [];
      try {
        if (await file.exists()) {
          events = jsonDecode(await file.readAsString()) as List;
        }
      } catch (_) {
        /* Empty report. */
      }
      return const JsonEncoder.withIndent('  ').convert({
        'format': 1,
        'app': 'MusicON',
        'platform': 'windows',
        'version': info.version,
        'system': Platform.operatingSystemVersion,
        'errors': events,
      });
    }
    final report = await channel
        .invokeMethod<String>('diagnosticsRead')
        .timeout(const Duration(seconds: 10));
    if (report == null) throw StateError('Diagnóstico indisponível.');
    return report;
  }
}
