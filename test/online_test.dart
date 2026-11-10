import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musicon/downloads/audio_network.dart';
import 'package:musicon/downloads/download_controller.dart';
import 'package:musicon/downloads/download_job.dart';
import 'package:musicon/downloads/download_store.dart';
import 'package:musicon/library_controller.dart';
import 'package:musicon/library_store.dart';
import 'package:musicon/models.dart';
import 'package:musicon/sources/direct_source.dart';
import 'package:musicon/sources/explorer_controller.dart';
import 'package:musicon/sources/jamendo_source.dart';
import 'package:musicon/sources/media_source.dart';

class MemoryLibrary implements LibraryStore {
  LibraryData data = LibraryData();
  bool fail = false;
  @override
  Future<LibraryData> load() async => LibraryData.fromJson(data.toJson());
  @override
  Future<void> save(LibraryData value) async {
    if (fail) throw StateError('disk full');
    data = LibraryData.fromJson(value.toJson());
  }
}

class MemoryDownloads implements DownloadStore {
  List<DownloadJob> data = [];
  @override
  Future<List<DownloadJob>> load() async =>
      data.map((j) => DownloadJob.fromJson(j.toJson())).toList();
  @override
  Future<void> save(List<DownloadJob> jobs) async {
    data = jobs.map((j) => DownloadJob.fromJson(j.toJson())).toList();
  }
}

final sampleBytes = <int>[73, 68, 51, ...List.filled(100, 0)];
const sampleTrack = Track(
  id: 'test-direct',
  title: 'Minha faixa',
  artist: 'Artista',
  location: 'https://example.com/song.mp3',
  source: TrackSource.online,
  downloadAllowed: true,
);

class FakeTransfer implements TransferClient {
  List<int> bytes = sampleBytes;
  int? length;
  String contentType = 'audio/mpeg';
  int opened = 0, closed = 0;
  Stream<List<int>>? stream;
  @override
  Future<AudioResponse> open(
    Uri uri,
    Cancellation cancel, {
    bool probe = false,
  }) async {
    opened++;
    return AudioResponse(
      uri: uri,
      status: 200,
      contentType: contentType,
      stream: stream ?? Stream.value(bytes),
      length: length,
      close: () {
        closed++;
      },
    );
  }
}

Map<String, Object> apiTrack(int id) => {
  'id': '$id',
  'name': 'Faixa $id',
  'artist_name': 'Artista',
  'audio': 'https://audio.example.com/$id.mp3',
  'audiodownload_allowed': true,
  'license_ccurl': 'https://creativecommons.org/licenses/by/4.0/',
};
http.Response apiResponse(List<dynamic> rows) => http.Response(
  jsonEncode({
    'headers': {'status': 'success'},
    'results': rows,
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for download');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test('routing respects host boundaries and rejects insecure links', () {
    expect(
      identifyLink(Uri.parse('https://m.youtube.com/watch?v=1')),
      LinkKind.youtube,
    );
    expect(
      identifyLink(Uri.parse('https://youtube.com.evil.test/a.mp3')),
      LinkKind.direct,
    );
    expect(
      identifyLink(Uri.parse('https://open.spotify.com/playlist/1')),
      LinkKind.spotify,
    );
    for (final value in [
      'http://example.com/a.mp3',
      'file:///music.mp3',
      'https://u:p@example.com/a',
      'https:///bad',
    ]) {
      expect(() => parseWebLink(value), throwsA(isA<SourceException>()));
    }
  });

  test(
    'audio probing rejects HTML even with mp3 extension and closes connection',
    () async {
      final client = FakeTransfer()
        ..bytes = utf8.encode('<html>Not audio</html>')
        ..contentType = 'text/html';
      final inspector = NetworkAudioInspector(client);
      await expectLater(
        inspector.inspect(Uri.parse(sampleTrack.location)),
        throwsA(isA<SourceException>()),
      );
      expect(client.closed, 1);
      client.bytes = sampleBytes;
      client.contentType = 'audio/mpeg';
      final direct = DirectAudioSource(inspector);
      final one = await direct.resolve(Uri.parse(sampleTrack.location));
      final two = await direct.resolve(Uri.parse(sampleTrack.location));
      expect(one.tracks.single.id, two.tracks.single.id);
      expect(one.tracks.single.downloadAllowed, isTrue);
      expect(client.closed, 3);
      expect(
        () => detectAudio(List.filled(20, 0), 'audio/mpeg'),
        throwsA(isA<SourceException>()),
      );
    },
  );

  test('Spotify and YouTube pages never reach the direct resolver', () async {
    final client = FakeTransfer();
    final registry = SourceRegistry([
      DirectAudioSource(NetworkAudioInspector(client)),
    ]);
    for (final link in [
      'https://youtu.be/abc',
      'https://open.spotify.com/playlist/1',
    ]) {
      await expectLater(
        registry.resolve(link),
        throwsA(isA<SourceException>()),
      );
    }
    expect(client.opened, 0);
  });

  test(
    'Jamendo search maps attribution and never enables offline downloads',
    () async {
      final source = JamendoSource(
        clientId: 'test',
        client: MockClient((request) async {
          expect(request.url.queryParameters['search'], 'jazz');
          expect(request.url.queryParameters['offset'], '20');
          expect(request.url.queryParameters['client_id'], 'test');
          return apiResponse(List.generate(20, apiTrack));
        }),
      );
      final result = await source.search(' jazz ', offset: 20);
      expect(result.hasMore, isTrue);
      expect(result.tracks.first.id, 'jamendo-0');
      expect(result.tracks.first.originUrl, 'https://www.jamendo.com/track/0');
      expect(result.tracks.every((t) => !t.downloadAllowed), isTrue);
    },
  );

  test(
    'Jamendo resolves a public playlist, handles rate limit and missing key',
    () async {
      final source = JamendoSource(
        clientId: 'test',
        client: MockClient((r) async {
          expect(r.url.path, '/v3.0/playlists/tracks/');
          expect(r.url.queryParameters['id'], '42');
          return apiResponse([
            {
              'name': 'Playlist',
              'tracks': [apiTrack(2), apiTrack(3)],
            },
          ]);
        }),
      );
      final result = await source.resolve(
        Uri.parse('https://www.jamendo.com/list/42/playlist'),
      );
      expect(result.tracks.length, 2);
      final limited = JamendoSource(
        clientId: 'test',
        client: MockClient((_) async => http.Response('', 429)),
      );
      await expectLater(limited.search(''), throwsA(isA<SourceException>()));
      final unconfigured = JamendoSource(
        clientId: '',
        client: MockClient((_) async => throw StateError('must not request')),
      );
      await expectLater(
        unconfigured.search(''),
        throwsA(isA<SourceException>()),
      );
    },
  );

  test('a stale search cannot replace newer results', () async {
    final first = Completer<http.Response>();
    final source = JamendoSource(
      clientId: 'test',
      client: MockClient((r) async {
        if (r.url.queryParameters['search'] == 'first') return first.future;
        return apiResponse([apiTrack(2)]);
      }),
    );
    final explorer = ExplorerController(
      registry: SourceRegistry([source]),
      jamendo: source,
    );
    final pending = explorer.search('first');
    await explorer.search('second');
    first.complete(apiResponse([apiTrack(1)]));
    await pending;
    expect(explorer.tracks.single.id, 'jamendo-2');
    expect(explorer.busy, isFalse);
    explorer.dispose();
  });

  group('downloads', () {
    late Directory root;
    late MemoryLibrary libraryStore;
    late LibraryController library;
    late MemoryDownloads store;
    late FakeTransfer client;
    late DownloadController downloads;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('musicon-test-');
      libraryStore = MemoryLibrary();
      library = LibraryController(libraryStore);
      await library.load();
      store = MemoryDownloads();
      client = FakeTransfer();
      downloads = DownloadController(
        client: client,
        store: store,
        library: library,
        directory: () async => root,
        maxBytes: 200,
      );
    });
    tearDown(() async {
      downloads.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await root.delete(recursive: true);
    });
    test(
      'complete file replaces online reference, preserving favorite and playlist',
      () async {
        await library.addResolved(sampleTrack);
        await library.toggleFavorite(sampleTrack);
        final playlist = (await library.createPlaylist('Viagem'))!;
        await library.addToPlaylist(playlist, sampleTrack);
        final job = await downloads.enqueue(sampleTrack);
        await until(() => job.status == DownloadStatus.completed);
        final local = library.findTrack(sampleTrack.id)!;
        expect(local.source, TrackSource.local);
        expect(await File(local.location).readAsBytes(), sampleBytes);
        expect(library.isFavorite(local), isTrue);
        expect(
          library.playlistTracks(playlist).single.source,
          TrackSource.local,
        );
        expect(root.listSync().where((f) => f.path.endsWith('.part')), isEmpty);
        expect(
          (await library.addResolved(sampleTrack)).source,
          TrackSource.local,
        );
        await expectLater(
          downloads.enqueue(sampleTrack),
          throwsA(isA<SourceException>()),
        );
      },
    );
    test(
      'truncation, HTML and oversized files never enter the library',
      () async {
        client.length = 150;
        final job = await downloads.enqueue(sampleTrack);
        await until(() => job.status == DownloadStatus.failed);
        expect(library.findTrack(sampleTrack.id), isNull);
        expect(root.listSync(), isEmpty);
        client.length = null;
        client.bytes = utf8.encode('<html>wrong file</html>');
        await downloads.retry(job);
        await until(() => job.status == DownloadStatus.failed);
        expect(root.listSync(), isEmpty);
        client.bytes = [73, 68, 51, ...List.filled(210, 0)];
        await downloads.retry(job);
        await until(() => job.status == DownloadStatus.failed);
        expect(root.listSync(), isEmpty);
        client.bytes = sampleBytes;
        await downloads.retry(job);
        await until(() => job.status == DownloadStatus.completed);
        expect(library.findTrack(sampleTrack.id)?.source, TrackSource.local);
      },
    );
    test('cancellation cleans partial file and permits retry', () async {
      final stream = StreamController<List<int>>();
      client.stream = stream.stream;
      final job = await downloads.enqueue(sampleTrack);
      await until(() => client.opened > 0);
      stream.add(sampleBytes);
      await until(() => job.received > 0);
      await downloads.cancel(job);
      stream.addError(const SocketException('connection closed'));
      await stream.close();
      await until(() => job.status == DownloadStatus.cancelled);
      expect(root.listSync(), isEmpty);
      expect(library.findTrack(sampleTrack.id), isNull);
      client.stream = null;
      await downloads.retry(job);
      await until(() => job.status == DownloadStatus.completed);
    });
    test('library persistence failure removes the finished file', () async {
      libraryStore.fail = true;
      final job = await downloads.enqueue(sampleTrack);
      await until(() => job.status == DownloadStatus.failed);
      expect(root.listSync(), isEmpty);
      expect(library.findTrack(sampleTrack.id), isNull);
    });
    test('interrupted jobs restore without silently restarting', () async {
      store.data = [
        DownloadJob(
          track: sampleTrack,
          status: DownloadStatus.downloading,
          received: 50,
        ),
      ];
      await downloads.load();
      expect(downloads.jobs.single.status, DownloadStatus.interrupted);
      expect(client.opened, 0);
      await downloads.retry(downloads.jobs.single);
      await until(
        () => downloads.jobs.single.status == DownloadStatus.completed,
      );
    });
    test(
      'concurrent initial enqueue loads the store once and deduplicates',
      () async {
        final jobs = await Future.wait([
          downloads.enqueue(sampleTrack),
          downloads.enqueue(sampleTrack),
        ]);
        expect(identical(jobs.first, jobs.last), isTrue);
        await until(() => jobs.first.status == DownloadStatus.completed);
        expect(client.opened, 1);
      },
    );
  });
}
