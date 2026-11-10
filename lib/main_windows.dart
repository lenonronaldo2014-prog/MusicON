// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app_preferences.dart';
import 'desktop/desktop_audio_service.dart';
import 'desktop/desktop_extractor.dart';
import 'desktop/windows_spotify_store.dart';
import 'diagnostics_service.dart';
import 'just_audio_engine.dart';
import 'library_controller.dart';
import 'library_store.dart';
import 'models.dart';
import 'newpipe_prototype.dart';
import 'online_services.dart';
import 'spotify/spotify_service.dart';
import 'ui.dart';
import 'update_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  const DiagnosticsService().install(desktop: true);
  JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
  JustAudioMediaKit.title = 'MusicON';
  JustAudioMediaKit.bufferSize = 8 * 1024 * 1024;
  final extractor = DesktopExtractor();
  final source = NewPipeSource(backend: extractor.invoke);
  final engine = JustAudioEngine(onlineSourceFactory: source.audioSource);
  final library = LibraryController(
    PreferencesLibraryStore(),
    device: DesktopAudioService(),
  );
  await library.load();
  final preferences = AppPreferences();
  await preferences.load();
  final spotify = SpotifyService(desktop: true, store: WindowsSpotifyStore());
  await spotify.load();
  final services = OnlineServices.create(library, source: source);
  await services.downloads.load();
  final capture = GlobalKey();
  runApp(
    RepaintBoundary(
      key: capture,
      child: MusicOnApp(
        library: library,
        engine: engine,
        discovery: PrototypeController(source, engine),
        services: services,
        preferences: preferences,
        updates: UpdateService(desktop: true),
        spotify: spotify,
        desktop: true,
      ),
    ),
  );
  final reportArg = args
      .where((arg) => arg.startsWith('--smoke-report='))
      .firstOrNull;
  if (reportArg != null) {
    unawaited(
      _smoke(
        reportArg.substring('--smoke-report='.length),
        extractor,
        source,
        engine,
        capture,
      ),
    );
  }
}

Future<void> _smoke(
  String output,
  DesktopExtractor extractor,
  NewPipeSource source,
  JustAudioEngine engine,
  GlobalKey capture,
) async {
  final report = <String, Object?>{'platform': 'windows', 'version': '0.8.0'};
  File? audio;
  try {
    await Future<void>.delayed(const Duration(seconds: 2));
    final renderer =
        capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await renderer.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$output.png').writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
    report['uiScreenshot'] = true;
    final ping = await extractor.invoke('ping', '') as Map;
    report['extractor'] = ping['version'];
    final search =
        await extractor.invoke('search', 'Blender Big Buck Bunny') as List;
    report['searchCount'] = search.length;
    final resolved =
        await extractor.invoke(
              'resolve',
              'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
            )
            as Map;
    report['onlineResolved'] = resolved['stream'] is String;
    // Low-volume generated PCM fixture; never added to the user's library.
    audio = File(
      p.join((await getTemporaryDirectory()).path, 'musicon-windows-smoke.wav'),
    );
    final samples = 44100 * 5;
    final bytes = ByteData(44 + samples * 2);
    void text(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    text(0, 'RIFF');
    bytes.setUint32(4, 36 + samples * 2, Endian.little);
    text(8, 'WAVE');
    text(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, 44100, Endian.little);
    bytes.setUint32(28, 88200, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    text(36, 'data');
    bytes.setUint32(40, samples * 2, Endian.little);
    await audio.writeAsBytes(bytes.buffer.asUint8List());
    await engine.playQueue([
      Track(
        id: 'windows-smoke',
        title: 'Validação local',
        artist: 'MusicON',
        location: audio.path,
        source: TrackSource.local,
      ),
    ], 0);
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (engine.position.inMilliseconds < 1200 &&
        engine.error == null &&
        DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    report['localPositionMs'] = engine.position.inMilliseconds;
    report['localError'] = engine.error;
    await engine.removeTrack('windows-smoke');
    final online = await source.resolve(
      'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
    );
    await engine.playQueue([online], 0);
    final onlineEnd = DateTime.now().add(const Duration(seconds: 30));
    while (engine.position.inMilliseconds < 1200 &&
        engine.error == null &&
        DateTime.now().isBefore(onlineEnd)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    report['onlinePositionMs'] = engine.position.inMilliseconds;
    report['onlineError'] = engine.error;
    await engine.removeTrack(online.id);
    report['passed'] =
        engine.error == null &&
        (report['localPositionMs'] as int) > 1000 &&
        (report['onlinePositionMs'] as int) > 1000 &&
        search.isNotEmpty;
  } catch (error) {
    report['passed'] = false;
    report['errorType'] = error.runtimeType.toString();
  } finally {
    if (audio != null && await audio.exists()) await audio.delete();
    await File(
      output,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  }
}
