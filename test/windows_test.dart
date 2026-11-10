import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:musicon/desktop/desktop_audio_service.dart';
import 'package:musicon/desktop/windows_spotify_store.dart';
import 'package:musicon/library_controller.dart';
import 'package:musicon/models.dart';
import 'package:musicon/newpipe_prototype.dart';
import 'package:musicon/spotify/spotify_service.dart';
import 'package:musicon/ui.dart';
import 'widget_test.dart' show MemoryStore, FakeEngine;

class DesktopMemorySession implements SpotifySessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String input) async {
    value = input;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class DesktopHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Windows session is encrypted for the current account and can be cleared',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'musicon-session-',
      );
      final file = File(p.join(temporary.path, 'session.dpapi'));
      final store = WindowsSpotifyStore(fileProvider: () async => file);
      try {
        const value = '{"access_token":"test-value-not-a-real-token"}';
        await store.write(value);
        expect(
          utf8.decode(await file.readAsBytes(), allowMalformed: true),
          isNot(contains('test-value')),
        );
        expect(await store.read(), value);
        await store.clear();
        expect(await store.read(), isNull);
      } finally {
        expect(p.isWithin(Directory.systemTemp.path, temporary.path), true);
        await temporary.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );
  test(
    'desktop scan deduplicates folders and rejects deleting outside the collection',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'musicon-folders-',
      );
      final songs = Directory(p.join(temporary.path, 'music'));
      await songs.create();
      final music = File(p.join(songs.path, 'Artista - Minha faixa.mp3'));
      await music.writeAsBytes([1, 2, 3]);
      final unrelated = File(p.join(temporary.path, 'outside.mp3'));
      await unrelated.writeAsBytes([4]);
      final service = DesktopAudioService(
        folders: () async => [songs.path, songs.path],
      );
      final watching = service.changes.listen((_) {});
      try {
        final first = await service.scan(requestPermission: false);
        expect(first.tracks, hasLength(1));
        expect(first.tracks.single.title, 'Minha faixa');
        expect(first.tracks.single.artist, 'Artista');
        expect(
          (await service.scan(requestPermission: false)).tracks.single.id,
          first.tracks.single.id,
        );
        await expectLater(
          service.delete(
            Track(
              id: 'device-outside',
              title: 'Fora',
              artist: '',
              location: unrelated.path,
              source: TrackSource.local,
              providerId: 'device',
            ),
          ),
          throwsStateError,
        );
        expect(await unrelated.exists(), true);
      } finally {
        await watching.cancel();
        expect(p.isWithin(Directory.systemTemp.path, temporary.path), true);
        await temporary.delete(recursive: true);
      }
    },
  );
  test(
    'desktop OAuth validates the loopback state and exchanges the same PKCE verifier',
    () async {
      const clientId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final store = DesktopMemorySession();
      late Uri authorization;
      final service = SpotifyService(
        desktop: true,
        clientId: clientId,
        store: store,
        browserLauncher: (uri) async {
          authorization = uri;
          final httpClient = HttpOverrides.runWithHttpOverrides(
            () => HttpClient(),
            DesktopHttpOverrides(),
          );
          try {
            final redirect = Uri.parse(uri.queryParameters['redirect_uri']!);
            final invalid = await (await httpClient.getUrl(
              redirect.replace(
                queryParameters: {'state': 'wrong', 'code': 'fake'},
              ),
            )).close();
            expect(invalid.statusCode, 400);
            await invalid.drain<void>();
            final accepted = await (await httpClient.getUrl(
              redirect.replace(
                queryParameters: {
                  'state': uri.queryParameters['state']!,
                  'code': 'test-code',
                },
              ),
            )).close();
            expect(accepted.statusCode, 200);
            await accepted.drain<void>();
          } finally {
            httpClient.close(force: true);
          }
        },
        client: MockClient((request) async {
          final body = Uri.splitQueryString(request.body);
          expect(body['redirect_uri'], 'http://127.0.0.1:8888/callback');
          expect(
            SpotifyService.challenge(body['code_verifier']!),
            authorization.queryParameters['code_challenge'],
          );
          expect(body.containsKey('client_secret'), false);
          return http.Response(
            jsonEncode({
              'access_token': 'test',
              'refresh_token': 'refresh',
              'expires_in': 3600,
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      await service.connect();
      expect(service.connected, true);
      await service.disconnect();
      expect(store.value, isNull);
    },
  );
  testWidgets(
    'Windows uses the wide navigation and original MusicON identity',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final library = LibraryController(MemoryStore());
      await library.load();
      final engine = FakeEngine();
      final discovery = PrototypeController(NewPipeSource(), engine);
      await tester.pumpWidget(
        MusicOnApp(
          library: library,
          engine: engine,
          discovery: discovery,
          desktop: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Dê play no seu mundo.'), findsOneWidget);
      expect(find.text('Do computador'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      discovery.dispose();
      library.dispose();
      engine.dispose();
    },
  );
}
