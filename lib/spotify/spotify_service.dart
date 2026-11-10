// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../sources/media_source.dart';

abstract class SpotifySessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSpotifyStore implements SpotifySessionStore {
  const SecureSpotifyStore();
  static const channel = MethodChannel('musicon/app');
  @override
  Future<String?> read() => channel.invokeMethod<String>('spotifySessionRead');
  @override
  Future<void> write(String value) =>
      channel.invokeMethod<void>('spotifySessionWrite', {'value': value});
  @override
  Future<void> clear() => channel.invokeMethod<void>('spotifySessionClear');
}

class SpotifyPlaylist {
  const SpotifyPlaylist(this.id, this.name);
  final String id, name;
}

class SpotifySong {
  const SpotifySong(this.id, this.title, this.artist);
  final String id, title, artist;
  String get query => '$title $artist';
}

class SpotifyService extends ChangeNotifier {
  SpotifyService({
    this.clientId = const String.fromEnvironment('SPOTIFY_CLIENT_ID'),
    http.Client? client,
    this.store = const SecureSpotifyStore(),
    Future<void> Function(Uri)? openBrowser,
  }) : _client = client ?? http.Client(),
       _openBrowser =
           openBrowser ??
           ((uri) => const MethodChannel(
             'musicon/app',
           ).invokeMethod<void>('spotifyAuthorize', {'url': uri.toString()}));
  final String clientId;
  final http.Client _client;
  final SpotifySessionStore store;
  final Future<void> Function(Uri) _openBrowser;
  Map<String, dynamic>? _session;
  HttpServer? _server;
  Future<void>? _refreshing;
  VoidCallback? _cancelLogin;
  int _epoch = 0;
  void cancelConnect() => _cancelLogin?.call();
  bool _disposed = false;
  bool get configured => RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(clientId);
  bool get connected => _session != null;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  String _random() => base64Url
      .encode(List.generate(48, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  static String challenge(String verifier) => base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');

  Future<void> load() async {
    if (!configured) return;
    try {
      final value = await store.read();
      if (value != null) {
        final session = jsonDecode(value) as Map<String, dynamic>;
        if (session['client_id'] == clientId &&
            session['refresh_token'] is String &&
            session['access_token'] is String &&
            session['expires_at'] is int) {
          _session = session;
        } else {
          await store.clear();
        }
      }
    } catch (_) {
      _session = null;
    }
    _changed();
  }

  Future<void> connect() async {
    if (!configured) {
      throw const SourceException(
        'A conexão Spotify ainda precisa ser ativada para o MusicON.',
      );
    }
    if (_server != null) {
      throw const SourceException('Uma conexão já está em andamento.');
    }
    final epoch = ++_epoch;
    final verifier = _random(), state = _random();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    final redirect = 'http://127.0.0.1:${server.port}/callback';
    final completed = Completer<String>();
    final subscription = server.listen((request) async {
      if (request.method != 'GET' ||
          request.uri.path != '/callback' ||
          request.uri.queryParameters['state'] != state) {
        request.response.statusCode = 400;
        request.response.write('Retorno invalido.');
        await request.response.close();
        return;
      }
      final code = request.uri.queryParameters['code'];
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<!doctype html><html lang="pt"><meta charset="utf-8"><title>MusicON</title><p>Volte ao MusicON para continuar.</p></html>',
      );
      await request.response.close();
      if (completed.isCompleted) return;
      if (code == null || request.uri.queryParameters.containsKey('error')) {
        completed.completeError(
          const SourceException('A conexão com o Spotify foi cancelada.'),
        );
      } else {
        completed.complete(code);
      }
    });
    // Attach the timeout/error handler before opening the browser.
    final timer = Timer(const Duration(minutes: 3), () {
      if (!completed.isCompleted) {
        completed.completeError(
          const SourceException('O login demorou demais. Tente novamente.'),
        );
      }
    });
    _cancelLogin = () {
      if (!completed.isCompleted) {
        completed.completeError(const SourceException('Conexão cancelada.'));
      }
    };
    final codeResult = completed.future;
    unawaited(
      codeResult.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    try {
      await _openBrowser(
        Uri.https('accounts.spotify.com', '/authorize', {
          'response_type': 'code',
          'client_id': clientId,
          'redirect_uri': redirect,
          'scope': 'playlist-read-private playlist-read-collaborative',
          'code_challenge_method': 'S256',
          'code_challenge': challenge(verifier),
          'state': state,
        }),
      );
      final code = await codeResult;
      final response = await _client
          .post(
            Uri.https('accounts.spotify.com', '/api/token'),
            body: {
              'grant_type': 'authorization_code',
              'code': code,
              'redirect_uri': redirect,
              'client_id': clientId,
              'code_verifier': verifier,
            },
          )
          .timeout(const Duration(seconds: 25));
      await _acceptToken(response, epoch);
    } finally {
      timer.cancel();
      _cancelLogin = null;
      await subscription.cancel();
      await server.close(force: true);
      if (identical(_server, server)) _server = null;
    }
  }

  Future<void> _acceptToken(http.Response response, int epoch) async {
    if (_disposed || epoch != _epoch) {
      throw const SourceException('Conexão cancelada.');
    }
    if (response.statusCode != 200) {
      throw const SourceException(
        'O Spotify não autorizou a conexão. Confira o cadastro do MusicON e as contas autorizadas.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final refresh = data['refresh_token'] ?? _session?['refresh_token'];
    if (data['access_token'] is! String ||
        refresh is! String ||
        data['expires_in'] is! int) {
      throw const SourceException('O Spotify retornou uma sessão incompleta.');
    }
    final session = <String, dynamic>{
      'client_id': clientId,
      'access_token': data['access_token'],
      'refresh_token': refresh,
      'expires_at':
          DateTime.now().millisecondsSinceEpoch +
          (data['expires_in'] as int) * 1000,
    };
    await store.write(jsonEncode(session));
    if (_disposed || epoch != _epoch) {
      await store.clear();
      throw const SourceException('Conexão cancelada.');
    }
    _session = session;
    _changed();
  }

  Future<void> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  Future<void> _doRefresh() async {
    final epoch = _epoch;
    final refresh = _session?['refresh_token'];
    if (refresh == null) {
      throw const SourceException('Conecte sua conta Spotify primeiro.');
    }
    final response = await _client
        .post(
          Uri.https('accounts.spotify.com', '/api/token'),
          body: {
            'grant_type': 'refresh_token',
            'refresh_token': refresh,
            'client_id': clientId,
          },
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode == 400 || response.statusCode == 401) {
      await disconnect();
    }
    await _acceptToken(response, epoch);
  }

  Future<Map<String, dynamic>> _get(Uri uri, {bool retry = true}) async {
    if (uri.scheme != 'https' ||
        uri.host != 'api.spotify.com' ||
        uri.userInfo.isNotEmpty ||
        !uri.path.startsWith('/v1/')) {
      throw const SourceException('Endereço Spotify inválido.');
    }
    if (_session == null) {
      throw const SourceException('Conecte sua conta Spotify primeiro.');
    }
    if ((_session!['expires_at'] as int) <=
        DateTime.now().millisecondsSinceEpoch + 30000) {
      await _refresh();
    }
    final response = await _client
        .get(
          uri,
          headers: {'Authorization': 'Bearer ${_session!['access_token']}'},
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode == 401 && retry) {
      await _refresh();
      return _get(uri, retry: false);
    }
    if (response.statusCode == 403) {
      throw const SourceException(
        'O Spotify não permitiu acesso. Confira se sua conta está autorizada no MusicON e se a playlist pertence a você.',
      );
    }
    if (response.statusCode == 429) {
      throw const SourceException(
        'O Spotify limitou as consultas. Aguarde e tente novamente.',
      );
    }
    if (response.statusCode != 200 ||
        response.bodyBytes.length > 4 * 1024 * 1024) {
      throw const SourceException(
        'Não foi possível carregar os dados do Spotify.',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> _pages(Uri uri) async {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    Uri? next = uri;
    while (next != null) {
      if (!seen.add(next.toString()) || seen.length > 100) {
        throw const SourceException(
          'Esta coleção é muito grande para importar nesta versão.',
        );
      }
      final page = await _get(next);
      items.addAll(
        (page['items'] as List? ?? []).whereType<Map>().map(
          (v) => Map<String, dynamic>.from(v),
        ),
      );
      final value = page['next'] as String?;
      next = value == null ? null : Uri.parse(value);
    }
    return items;
  }

  Future<List<SpotifyPlaylist>> playlists() async =>
      (await _pages(
            Uri.https('api.spotify.com', '/v1/me/playlists', {'limit': '50'}),
          ))
          .where((p) => p['id'] is String)
          .map(
            (p) => SpotifyPlaylist(
              p['id'] as String,
              p['name'] as String? ?? 'Playlist Spotify',
            ),
          )
          .toList();
  static String playlistId(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'open.spotify.com' ||
        uri.userInfo.isNotEmpty) {
      throw const SourceException('Cole um link de playlist do Spotify.');
    }
    final match = RegExp(
      r'^/(?:intl-[a-z]{2}/)?playlist/([A-Za-z0-9]+)$',
    ).firstMatch(uri.path);
    if (match == null) {
      throw const SourceException('Esse link não é uma playlist Spotify.');
    }
    return match[1]!;
  }

  Future<SpotifyPlaylist> playlistFromLink(String link) async {
    final id = playlistId(link);
    final data = await _get(Uri.https('api.spotify.com', '/v1/playlists/$id'));
    return SpotifyPlaylist(id, data['name'] as String? ?? 'Playlist Spotify');
  }

  Future<List<SpotifySong>> songs(String playlistId) async {
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(playlistId)) {
      throw const SourceException('Playlist inválida.');
    }
    final items = await _pages(
      Uri.https('api.spotify.com', '/v1/playlists/$playlistId/items', {
        'limit': '50',
      }),
    );
    return items
        .map((v) => v['item'] ?? v['track'])
        .whereType<Map>()
        .where(
          (v) =>
              v['type'] == 'track' &&
              v['is_local'] != true &&
              v['id'] is String,
        )
        .map(
          (v) => SpotifySong(
            v['id'] as String,
            v['name'] as String? ?? 'Música',
            (v['artists'] as List? ?? [])
                .whereType<Map>()
                .map((a) => a['name'] as String? ?? '')
                .join(', '),
          ),
        )
        .toList();
  }

  Future<void> disconnect() async {
    _epoch++;
    cancelConnect();
    await store.clear();
    _session = null;
    _changed();
  }

  @override
  void dispose() {
    cancelConnect();
    _disposed = true;
    _server?.close(force: true);
    _client.close();
    super.dispose();
  }
}
