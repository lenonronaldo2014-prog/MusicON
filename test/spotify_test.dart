import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musicon/spotify/spotify_service.dart';
import 'package:musicon/spotify/spotify_page.dart';
import 'package:musicon/library_controller.dart';
import 'package:musicon/newpipe_prototype.dart';
import 'package:musicon/models.dart';
import 'package:musicon/sources/media_source.dart';
import 'widget_test.dart' show MemoryStore;

class RealHttp extends HttpOverrides {}

const clientId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class SessionMemory implements SpotifySessionStore {
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

Map<String, dynamic> session({bool expired = false}) => {
  'client_id': clientId,
  'access_token': 'test-access',
  'refresh_token': 'test-refresh',
  'expires_at':
      DateTime.now().millisecondsSinceEpoch + (expired ? -1000 : 3600000),
};
http.Response jsonResponse(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);
void main() {
  test(
    'PKCE uses RFC 7636 S256 and Spotify playlist links are strictly validated',
    () {
      expect(
        SpotifyService.challenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
      expect(
        SpotifyService.playlistId(
          'https://open.spotify.com/playlist/abc123?si=test',
        ),
        'abc123',
      );
      expect(
        () => SpotifyService.playlistId('https://evil.example/playlist/abc123'),
        throwsA(isA<SourceException>()),
      );
      expect(
        () =>
            SpotifyService.playlistId('https://open.spotify.com/track/abc123'),
        throwsA(isA<SourceException>()),
      );
    },
  );
  test(
    'real loopback callback rejects wrong state and PKCE exchanges code without a secret',
    () async {
      final store = SessionMemory();
      var tokenCalls = 0;
      late Uri authorization;
      final service = SpotifyService(
        clientId: clientId,
        store: store,
        openBrowser: (uri) async {
          authorization = uri;
          final callback = Uri.parse(uri.queryParameters['redirect_uri']!);
          final client = HttpOverrides.runWithHttpOverrides(() => HttpClient(), RealHttp());
          try {
            final invalid = await client.getUrl(
              callback.replace(
                queryParameters: {'code': 'wrong', 'state': 'wrong'},
              ),
            );
            final denied = await invalid.close();
            expect(denied.statusCode, 400);
            await denied.drain<void>();
            expect(tokenCalls, 0);
            final valid = await client.getUrl(
              callback.replace(
                queryParameters: {
                  'code': 'test-code',
                  'state': uri.queryParameters['state']!,
                },
              ),
            );
            final accepted = await valid.close();
            expect(accepted.statusCode, 200);
            await accepted.drain<void>();
          } finally {
            client.close(force: true);
          }
        },
        client: MockClient((request) async {
          tokenCalls++;
          final body = Uri.splitQueryString(request.body);
          expect(body['code'], 'test-code');
          expect(body.containsKey('client_secret'), isFalse);
          expect(
            SpotifyService.challenge(body['code_verifier']!),
            authorization.queryParameters['code_challenge'],
          );
          return jsonResponse({
            'access_token': 'access',
            'refresh_token': 'refresh',
            'expires_in': 3600,
          });
        }),
      );
      await service.connect();
      expect(service.connected, isTrue);
      expect(tokenCalls, 1);
      expect(jsonDecode(store.value!)['refresh_token'], 'refresh');
      await service.disconnect();
      expect(store.value, isNull);
      expect(service.connected, isFalse);
      service.dispose();
    },
  );
  test(
    'playlist pagination, token refresh, new item shape and revoked session are handled',
    () async {
      final store = SessionMemory()..value = jsonEncode(session(expired: true));
      var refreshes = 0;
      final service = SpotifyService(
        clientId: clientId,
        store: store,
        client: MockClient((r) async {
          if (r.url.host == 'accounts.spotify.com') {
            refreshes++;
            return jsonResponse({
              'access_token': 'renewed',
              'expires_in': 3600,
            });
          }
          expect(r.headers['Authorization'], 'Bearer renewed');
          if (r.url.path.endsWith('/items')) {
            return jsonResponse({
              'next': null,
              'items': [
                {
                  'item': {
                    'id': 'one',
                    'type': 'track',
                    'name': 'Minha faixa',
                    'artists': [
                      {'name': 'Artista'},
                    ],
                  },
                },
                {'item': null},
                {
                  'item': {'type': 'episode', 'id': 'podcast'},
                },
              ],
            });
          }
          return jsonResponse({
            'items': [
              {
                'id': r.url.queryParameters['offset'] == null ? 'p1' : 'p2',
                'name': 'Coleção',
              },
            ],
            'next': r.url.queryParameters['offset'] == null
                ? 'https://api.spotify.com/v1/me/playlists?offset=50'
                : null,
          });
        }),
      );
      await service.load();
      expect((await service.playlists()).map((p) => p.id), ['p1', 'p2']);
      expect(refreshes, 1);
      expect((await service.songs('p1')).single.query, 'Minha faixa Artista');
      expect(jsonDecode(store.value!)['refresh_token'], 'test-refresh');
      await service.disconnect();
      service.dispose();
    },
  );
  test(
    'pagination never leaks authorization outside the Spotify API',
    () async {
      final store = SessionMemory()..value = jsonEncode(session());
      var calls = 0;
      final service = SpotifyService(
        clientId: clientId,
        store: store,
        client: MockClient((r) async {
          calls++;
          return jsonResponse({
            'items': [],
            'next': 'https://other.example/steal',
          });
        }),
      );
      await service.load();
      await expectLater(service.playlists(), throwsA(isA<SourceException>()));
      expect(calls, 1);
      service.dispose();
    },
  );
  test(
    'importing confirmed versions keeps order and favorites without duplicate tracks',
    () async {
      final library = LibraryController(MemoryStore());
      await library.load();
      const track = Track(
        id: 'youtube-one',
        title: 'Uma',
        artist: 'A',
        location: 'https://youtu.be/one',
        originUrl: 'https://youtu.be/one',
        source: TrackSource.online,
        providerId: 'youtube',
      );
      await library.toggleFavorite(track);
      final playlist = await library.importCollection('Meu Spotify', [
        track,
        track,
      ]);
      expect(playlist.trackIds, [track.id]);
      expect(library.isFavorite(track), isTrue);
      expect(library.tracks.where((t) => t.id == track.id), hasLength(1));
      library.dispose();
    },
  );
  testWidgets(
    'Spotify is optional and unavailable configuration is explained',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final library = LibraryController(MemoryStore());
      await library.load();
      final service = SpotifyService(clientId: '', store: SessionMemory());
      await tester.pumpWidget(
        MaterialApp(
          home: SpotifyPage(
            spotify: service,
            library: library,
            source: NewPipeSource(),
          ),
        ),
      );
      expect(find.textContaining('em preparação'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      library.dispose();
    },
  );
}
