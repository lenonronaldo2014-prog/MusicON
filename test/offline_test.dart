import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicon/downloads/audio_network.dart';
import 'package:musicon/downloads/download_controller.dart';
import 'package:musicon/downloads/download_job.dart';
import 'package:musicon/library_controller.dart';
import 'package:musicon/models.dart';
import 'package:musicon/sources/media_source.dart';
import 'online_test.dart'
    show MemoryLibrary, MemoryDownloads, FakeTransfer, until;

const track = Track(
  id: 'youtube-page',
  title: 'Minha faixa',
  artist: 'A',
  location: 'https://youtu.be/page',
  originUrl: 'https://youtu.be/page',
  source: TrackSource.online,
  providerId: 'youtube',
  downloadAllowed: true,
);
final webm = [0x1a, 0x45, 0xdf, 0xa3, ...List.filled(100, 0)];
void main() {
  test(
    'offline download persists a complete local file, preserves playlists and can be removed',
    () async {
      final root = await Directory.systemTemp.createTemp('musicon-offline-');
      final store = MemoryLibrary();
      final history = MemoryDownloads();
      final library = LibraryController(store);
      await library.load();
      await library.toggleFavorite(track);
      final playlist = (await library.createPlaylist('Favoritas'))!;
      await library.addToPlaylist(playlist, track);
      final direct = FakeTransfer();
      final downloads = DownloadController(
        client: direct,
        store: history,
        library: library,
        directory: () async => root,
        openTrack: (value, cancel) async => AudioResponse(
          uri: Uri.parse('https://test.googlevideo.com/audio?temporary=secret'),
          status: 200,
          contentType: 'audio/webm',
          length: webm.length,
          stream: Stream.value(webm),
          close: () {},
        ),
      );
      final job = await downloads.enqueue(track);
      await until(() => job.status == DownloadStatus.completed);
      expect(direct.opened, 0);
      final local = library.findTrack(track.id)!;
      expect(local.source, TrackSource.local);
      expect(await File(local.location).readAsBytes(), webm);
      expect(library.playlistTracks(playlist).single.location, local.location);
      expect(library.isFavorite(local), isTrue);
      expect(
        jsonEncode(history.data.map((j) => j.toJson()).toList()),
        isNot(contains('temporary=')),
      );
      final restored = LibraryController(store);
      await restored.load();
      expect(restored.findTrack(track.id)!.source, TrackSource.local);
      await downloads.removeOffline(local);
      expect(await File(local.location).exists(), isFalse);
      expect(library.findTrack(track.id)!.location, track.originUrl);
      expect(library.isFavorite(track), isTrue);
      expect(playlist.trackIds, [track.id]);
      final again = await downloads.enqueue(library.findTrack(track.id)!);
      await until(() => again.status == DownloadStatus.completed);
      downloads.dispose();
      library.dispose();
      restored.dispose();
      await root.delete(recursive: true);
    },
  );
  test(
    'truncated offline transfer leaves no playable partial file and retry works',
    () async {
      final root = await Directory.systemTemp.createTemp('musicon-offline-');
      final library = LibraryController(MemoryLibrary());
      await library.load();
      var truncated = true;
      final downloads = DownloadController(
        client: FakeTransfer(),
        store: MemoryDownloads(),
        library: library,
        directory: () async => root,
        openTrack: (value, cancel) async => AudioResponse(
          uri: Uri.parse('https://test.googlevideo.com/audio'),
          status: 200,
          contentType: 'audio/webm',
          length: webm.length,
          stream: Stream.value(truncated ? webm.take(20).toList() : webm),
          close: () {},
        ),
      );
      final job = await downloads.enqueue(track);
      await until(() => job.status == DownloadStatus.failed);
      expect(await root.list().toList(), isEmpty);
      expect(library.findTrack(track.id)?.source, isNot(TrackSource.local));
      truncated = false;
      await downloads.retry(job);
      await until(() => job.status == DownloadStatus.completed);
      expect(library.findTrack(track.id)!.source, TrackSource.local);
      downloads.dispose();
      library.dispose();
      await root.delete(recursive: true);
    },
  );
  test(
    'remove offline refuses files outside the app download directory',
    () async {
      final root = await Directory.systemTemp.createTemp('musicon-offline-');
      final outside = await File(
        '${root.path}-other.mp3',
      ).writeAsBytes([1, 2, 3]);
      final library = LibraryController(MemoryLibrary());
      await library.load();
      await library.addResolved(track.asLocal(outside.path));
      final downloads = DownloadController(
        client: FakeTransfer(),
        store: MemoryDownloads(),
        library: library,
        directory: () async => root,
      );
      await expectLater(
        downloads.removeOffline(library.findTrack(track.id)!),
        throwsA(isA<SourceException>()),
      );
      expect(await outside.exists(), isTrue);
      downloads.dispose();
      library.dispose();
      await outside.delete();
      await root.delete(recursive: true);
    },
  );
  test(
    'restart recovers a file committed before its download history',
    () async {
      final root = await Directory.systemTemp.createTemp('musicon-offline-');
      final file = await File(
        '${root.path}/musicon-recovered.webm',
      ).writeAsBytes(webm);
      final library = LibraryController(MemoryLibrary());
      await library.load();
      await library.addResolved(track.asLocal(file.path));
      final history = MemoryDownloads()
        ..data = [
          DownloadJob(track: track, status: DownloadStatus.downloading),
        ];
      final downloads = DownloadController(
        client: FakeTransfer(),
        store: history,
        library: library,
        directory: () async => root,
      );
      await downloads.load();
      expect(downloads.jobs.single.status, DownloadStatus.completed);
      expect(downloads.jobs.single.localPath, file.path);
      expect(downloads.jobs.single.received, webm.length);
      downloads.dispose();
      library.dispose();
      await root.delete(recursive: true);
    },
  );
}
