// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'just_audio_engine.dart';
import 'newpipe_prototype.dart';
import 'library_controller.dart';
import 'library_store.dart';
import 'ui.dart';
import 'app_preferences.dart';
import 'update_service.dart';
import 'online_services.dart';
import 'spotify/spotify_service.dart';
import 'models.dart';
import 'device_audio_service.dart';
import 'diagnostics_service.dart';
import 'downloads/download_job.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const DiagnosticsService().install();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.musicon.prototype.playback',
    androidNotificationChannelName: 'Reprodução MusicON',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_stat_music',
  );
  await (await AudioSession.instance).configure(
    const AudioSessionConfiguration.music(),
  );
  final source = NewPipeSource();
  final engine = JustAudioEngine(onlineSourceFactory: source.audioSource);
  final controller = PrototypeController(source, engine);
  final library = LibraryController(PreferencesLibraryStore(), device: AndroidDeviceAudioService());
  await library.load();
  final preferences = AppPreferences();
  await preferences.load();
  final spotify = SpotifyService();
  await spotify.load();
  final services = OnlineServices.create(library, source: source);
  await services.downloads.load();
  runApp(
    MusicOnApp(
      library: library,
      engine: engine,
      services: services,
      spotify: spotify,
      discovery: controller,
      preferences: preferences,
      updates: UpdateService(),
    ),
  );
  if (kDebugMode && const bool.fromEnvironment('NEWPIPE_OFFLINE_PROBE')) {
    unawaited(runOfflineProbe(library, services, engine, source));
  }
  if (kDebugMode && const bool.fromEnvironment('NEWPIPE_PROBE')) {
    unawaited(runProbe(controller));
  }
}

// Explicit opt-in live smoke test. Logs contain no signed stream URLs.
Future<void> runProbe(PrototypeController controller) async {
  final output = File(
    '${(await getApplicationDocumentsDirectory()).path}/newpipe-probe.json',
  );
  final report = <String, Object?>{'extractor': 'v0.27.0'};
  Future<void> record(String stage) async {
    report['stage'] = stage;
    await output.writeAsString(jsonEncode(report), flush: true);
    debugPrint('MUSICON_PROBE $stage');
  }

  try {
    await record('searching');
    await controller.search('Blender Big Buck Bunny');
    report['searchCount'] = controller.results.length;
    if (controller.error != null || controller.results.isEmpty) {
      throw StateError(controller.error ?? 'No results');
    }
    await record('search_ok');
    // Blender Foundation public short film; no account, cookies or credentials.
    await controller.play(
      const VideoResult(
        title: 'Big Buck Bunny',
        artist: 'Blender',
        url: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
      ),
    );
    if (controller.error != null) throw StateError(controller.error!);
    final deadline = DateTime.now().add(const Duration(seconds: 40));
    while (controller.engine.position.inSeconds < 3) {
      if (controller.engine.error != null) {
        throw StateError(controller.engine.error!);
      }
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Playback did not advance');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    report['positionBefore'] = controller.engine.position.inSeconds;
    await record('ready_for_screen_off');
    await Future<void>.delayed(const Duration(seconds: 25));
    report['positionAfter'] = controller.engine.position.inSeconds;
    report['playing'] = controller.engine.playing;
    report['advanced'] =
        (report['positionAfter'] as int) - (report['positionBefore'] as int) >=
        15;
    if (report['advanced'] != true || report['playing'] != true) {
      throw StateError('Background playback stopped');
    }
    await record('playback_pass');
    await controller.engine.toggle();
  } catch (e) {
    report['error'] = e.toString();
    await record('failed');
    if (controller.engine.playing) await controller.engine.toggle();
  }
}

// Opt-in integration probe. No account data or signed media addresses are logged.
Future<void> runOfflineProbe(
  LibraryController library,
  OnlineServices services,
  JustAudioEngine engine,
  NewPipeSource source,
) async {
  final file = File(
    '${(await getApplicationDocumentsDirectory()).path}/offline-probe.json',
  );
  final report = <String, Object?>{};
  Future<void> record(String stage) async {
    report['stage'] = stage;
    await file.writeAsString(jsonEncode(report), flush: true);
    debugPrint('MUSICON_OFFLINE_PROBE $stage');
  }

  try {
    await record('preparing');
    const store = SecureSpotifyStore();
    if (await store.read() == null) {
      try {
        await store.write('musicon-probe');
        report['secureStoreRoundtrip'] = await store.read() == 'musicon-probe';
      } finally {
        await store.clear();
      }
    }
    final resolved = await source.resolve(
      'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
    );
    final stable = await library.addResolved(resolved);
    final job = await services.downloads.enqueue(stable);
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (job.status == DownloadStatus.downloading ||
        job.status == DownloadStatus.queued) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Download timed out');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (job.status != DownloadStatus.completed) {
      throw StateError(job.message ?? job.label);
    }
    report['bytes'] = job.received;
    await record('ready_for_disconnect');
    await Future<void>.delayed(const Duration(seconds: 12));
    final restored = LibraryController(PreferencesLibraryStore());
    await restored.load();
    final local = restored.findTrack(stable.id)!;
    report['localAfterReload'] =
        local.source == TrackSource.local &&
        await File(local.location).exists();
    if (report['localAfterReload'] != true) {
      throw StateError('Local file not restored');
    }
    await engine.playQueue([local], 0);
    final playbackDeadline = DateTime.now().add(const Duration(seconds: 30));
    while (engine.position.inSeconds < 3) {
      if (engine.error != null || DateTime.now().isAfter(playbackDeadline)) {
        throw StateError(engine.error ?? 'Playback did not advance');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    report['position'] = engine.position.inSeconds;
    report['playing'] = engine.playing;
    report['source'] = engine.current?.source.name;
    await record('pass');
    if (engine.playing) await engine.toggle();
    restored.dispose();
  } catch (e) {
    report['error'] = e.toString();
    await record('failed');
  }
}
