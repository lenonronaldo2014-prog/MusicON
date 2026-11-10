import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class ChoiceSpotify extends SpotifyService {
  ChoiceSpotify() : super(clientId: clientId, store: SessionMemory());
  bool? selectedApp;
  @override
  Future<bool> spotifyAppAvailable() async => true;
  @override
  Future<void> connect({bool useSpotifyApp = false}) async {
    selectedApp = useSpotifyApp;
    throw const SourceException('Teste de escolha concluído.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'playlist listing denial explains owner Premium and keeps the saved session',
    () async {
      final store = SessionMemory()..value = jsonEncode(session());
      final original = store.value;
      final service = SpotifyService(
        clientId: clientId,
        store: store,
        client: MockClient((_) async => jsonResponse({}, 403)),
      );
      addTearDown(service.dispose);
      await service.load();
      await expectLater(
        service.playlists(),
        throwsA(
          isA<SourceException>().having(
            (e) => e.message,
            'eligibility guidance',
            allOf(contains('Premium'), contains('usuários autorizados')),
          ),
        ),
      );
      expect(service.connected, isTrue);
      expect(store.value, original);
    },
  );
  test(
    'cancelling browser authorization discards its reply and allows a fresh login',
    () async {
      const channel = MethodChannel('musicon/app');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final pending = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      var attempts = 0, tokenCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'spotifyAppCancel') {
          if (!pending.isCompleted) {
            pending.completeError(PlatformException(code: 'cancelled'));
          }
          return null;
        }
        expect(call.method, 'spotifyBrowserAuthorize');
        attempts++;
        if (attempts == 1) {
          started.complete();
          return pending.future;
        }
        final args = call.arguments as Map;
        return {'code': 'fresh-test-code', 'state': args['state']};
      });
      final store = SessionMemory();
      final service = SpotifyService(
        clientId: clientId,
        store: store,
        client: MockClient((request) async {
          tokenCalls++;
          expect(Uri.splitQueryString(request.body)['code'], 'fresh-test-code');
          return jsonResponse({
            'access_token': 'test-access',
            'refresh_token': 'test-refresh',
            'expires_in': 3600,
          });
        }),
      );
      addTearDown(service.dispose);
      final cancelled = expectLater(
        service.connect(),
        throwsA(isA<SourceException>()),
      );
      await started.future;
      await expectLater(service.connect(), throwsA(isA<SourceException>()));
      service.cancelConnect();
      await cancelled;
      expect(tokenCalls, 0);
      expect(store.value, isNull);
      await service.connect();
      expect(tokenCalls, 1);
      expect(service.connected, isTrue);
    },
  );
  test(
    'official native authorization validates state and exchanges the same PKCE verifier',
    () async {
      const channel = MethodChannel('musicon/app');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      late Map<String, dynamic> authorization;
      var invalidState = true;
      var tokenCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'spotifyAppCancel') return null;
        authorization = Map<String, dynamic>.from(call.arguments as Map);
        return {
          'code': 'native-test-code',
          'state': invalidState ? 'wrong' : authorization['state'],
        };
      });
      final store = SessionMemory();
      final service = SpotifyService(
        clientId: clientId,
        store: store,
        client: MockClient((request) async {
          tokenCalls++;
          final body = Uri.splitQueryString(request.body);
          expect(body['redirect_uri'], SpotifyService.nativeRedirect);
          expect(body['code_verifier'], authorization['verifier']);
          expect(
            SpotifyService.challenge(body['code_verifier']!),
            authorization['challenge'],
          );
          expect(body['code'], 'native-test-code');
          expect(body.containsKey('client_secret'), isFalse);
          return jsonResponse({
            'access_token': 'native-test-access',
            'refresh_token': 'native-test-refresh',
            'expires_in': 3600,
          });
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.connect(useSpotifyApp: true),
        throwsA(isA<SourceException>()),
      );
      expect(tokenCalls, 0);
      expect(store.value, isNull);
      invalidState = false;
      await service.connect(useSpotifyApp: true);
      expect(tokenCalls, 1);
      expect(service.connected, isTrue);
    },
  );
  testWidgets('login chooser honors Spotify app or browser selection', (
    tester,
  ) async {
    for (final useApp in [true, false]) {
      final library = LibraryController(MemoryStore());
      await library.load();
      final spotify = ChoiceSpotify();
      await tester.pumpWidget(
        MaterialApp(
          home: SpotifyPage(
            spotify: spotify,
            library: library,
            source: NewPipeSource(),
          ),
        ),
      );
      await tester.tap(find.text('Conectar ao Spotify'));
      await tester.pumpAndSettle();
      expect(find.text('Como deseja conectar?'), findsOneWidget);
      await tester.tap(
        find.text(useApp ? 'Pelo aplicativo Spotify' : 'Pelo navegador'),
      );
      await tester.pumpAndSettle();
      expect(spotify.selectedApp, useApp);
      expect(find.text('Tentar conectar novamente'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      spotify.dispose();
      library.dispose();
    }
  });
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
    'browser authorization uses Android callback and retries only a transient token DNS failure',
    () async {
      const channel = MethodChannel('musicon/app');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final store = SessionMemory();
      var tokenCalls = 0;
      late Map<String, dynamic> authorization;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'spotifyAppCancel') return null;
        expect(call.method, 'spotifyBrowserAuthorize');
        authorization = Map<String, dynamic>.from(call.arguments as Map);
        return {'code': 'test-code', 'state': authorization['state']};
      });
      final service = SpotifyService(
        clientId: clientId,
        store: store,
        client: MockClient((request) async {
          tokenCalls++;
          final body = Uri.splitQueryString(request.body);
          expect(body['code'], 'test-code');
          expect(body['redirect_uri'], 'musicon://spotify/callback');
          expect(body.containsKey('client_secret'), isFalse);
          expect(
            SpotifyService.challenge(body['code_verifier']!),
            authorization['challenge'],
          );
          if (tokenCalls == 1) {
            throw http.ClientException(
              "Failed host lookup: 'accounts.spotify.com'",
              request.url,
            );
          }
          return jsonResponse({
            'access_token': 'access',
            'refresh_token': 'refresh',
            'expires_in': 3600,
          });
        }),
      );
      addTearDown(service.dispose);
      await service.connect();
      expect(service.connected, isTrue);
      expect(tokenCalls, 2);
      await service.disconnect();
      expect(store.value, isNull);
    },
  );
  test(
    'persistent DNS failure is bounded, readable and preserves refresh credentials',
    () async {
      final store = SessionMemory()..value = jsonEncode(session(expired: true));
      final original = store.value;
      var calls = 0;
      var offline = true;
      final service = SpotifyService(
        clientId: clientId,
        store: store,
        client: MockClient((request) async {
          calls++;
          if (offline) {
            throw const SocketException(
              "Failed host lookup: 'accounts.spotify.com'",
              osError: OSError('No address associated with hostname', 7),
            );
          }
          if (request.url.host == 'accounts.spotify.com') {
            return jsonResponse({
              'access_token': 'renewed',
              'expires_in': 3600,
            });
          }
          return jsonResponse({'items': [], 'next': null});
        }),
      );
      addTearDown(service.dispose);
      await service.load();
      await expectLater(
        service.playlists(),
        throwsA(
          isA<SourceException>().having(
            (error) => error.message,
            'friendly network guidance',
            allOf(
              contains('Wi-Fi'),
              contains('DNS privado'),
              isNot(contains('SocketException')),
            ),
          ),
        ),
      );
      expect(calls, 3);
      expect(store.value, original);
      expect(service.connected, isTrue);
      offline = false;
      expect(await service.playlists(), isEmpty);
      expect(calls, 5);
      expect(jsonDecode(store.value!)['refresh_token'], 'test-refresh');
    },
  );
  test('playlist reads also recover transient DNS failures', () async {
    final store = SessionMemory()..value = jsonEncode(session());
    var calls = 0;
    final service = SpotifyService(
      clientId: clientId,
      store: store,
      client: MockClient((request) async {
        if (++calls == 1) {
          throw const SocketException("Failed host lookup: 'api.spotify.com'");
        }
        return jsonResponse({
          'items': [
            {'id': 'one', 'name': 'Minha playlist'},
          ],
          'next': null,
        });
      }),
    );
    addTearDown(service.dispose);
    await service.load();
    expect((await service.playlists()).single.name, 'Minha playlist');
    expect(calls, 2);
  });
  test('timeouts and HTTP errors are not blindly retried', () async {
    for (final status in [0, 403, 429]) {
      final store = SessionMemory()
        ..value = jsonEncode(session(expired: status == 0));
      var calls = 0;
      final service = SpotifyService(
        clientId: clientId,
        store: store,
        client: MockClient((request) async {
          calls++;
          if (status == 0) throw TimeoutException('test timeout');
          return jsonResponse({}, status);
        }),
      );
      await service.load();
      await expectLater(service.playlists(), throwsA(isA<SourceException>()));
      expect(calls, 1);
      expect(service.connected, isTrue);
      service.dispose();
    }
  });
  test('disconnect cancels pending DNS retry before another request', () async {
    final store = SessionMemory()..value = jsonEncode(session());
    final attempted = Completer<void>();
    var calls = 0;
    final service = SpotifyService(
      clientId: clientId,
      store: store,
      client: MockClient((request) async {
        calls++;
        attempted.complete();
        throw const SocketException("Failed host lookup: 'api.spotify.com'");
      }),
    );
    addTearDown(service.dispose);
    await service.load();
    final result = expectLater(
      service.playlists(),
      throwsA(isA<SourceException>()),
    );
    await attempted.future;
    await service.disconnect();
    await result;
    expect(calls, 1);
    expect(store.value, isNull);
  });
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
