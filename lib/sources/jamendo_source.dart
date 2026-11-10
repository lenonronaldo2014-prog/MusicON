import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';
import 'media_source.dart';

class JamendoSource implements MediaSource {
  JamendoSource({
    required this.clientId,
    required this.client,
    this.demo = false,
  });
  final String clientId;
  final http.Client client;
  final bool demo;
  bool get configured => clientId.isNotEmpty;
  @override
  String get id => 'jamendo';
  @override
  bool accepts(Uri uri) => identifyLink(uri) == LinkKind.jamendo;

  Future<List<dynamic>> _get(String method, Map<String, String> params) async {
    if (!configured) {
      throw const SourceException(
        'O catálogo Jamendo ainda não foi configurado nesta versão. Links diretos continuam disponíveis.',
      );
    }
    final uri = Uri.https('api.jamendo.com', '/v3.0/$method/', {
      'client_id': clientId,
      'format': 'json',
      'audioformat': 'mp32',
      'imagesize': '300',
      ...params,
    });
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 429) {
        throw const SourceException(
          'O catálogo recebeu muitas consultas. Aguarde um pouco e tente novamente.',
        );
      }
      if (response.statusCode != 200) {
        throw const SourceException(
          'O catálogo está indisponível. Tente novamente.',
        );
      }
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final headers = body['headers'] as Map<String, dynamic>?;
      if (headers?['status'] != 'success') {
        throw const SourceException(
          'O Jamendo não aceitou a consulta. Verifique a configuração do catálogo.',
        );
      }
      return body['results'] as List<dynamic>;
    } on SourceException {
      rethrow;
    } on TimeoutException {
      throw const SourceException(
        'O catálogo demorou para responder. Tente novamente.',
      );
    } catch (_) {
      throw const SourceException(
        'Não foi possível consultar o Jamendo. Verifique sua conexão.',
      );
    }
  }

  Track? _track(Map<String, dynamic> row) {
    final audio = Uri.tryParse(row['audio'] as String? ?? '');
    if (audio == null ||
        audio.host.isEmpty ||
        audio.userInfo.isNotEmpty ||
        !['http', 'https'].contains(audio.scheme)) {
      return null;
    }
    // Jamendo documents HTTPS endpoints; upgrade old HTTP stream links.
    final secured = audio.scheme == 'http'
        ? audio.replace(scheme: 'https')
        : audio;
    final trackId = row['id']?.toString();
    if (trackId == null || !RegExp(r'^\d+$').hasMatch(trackId)) return null;
    return Track(
      id: 'jamendo-$trackId',
      title: row['name'] as String? ?? 'Sem título',
      artist: row['artist_name'] as String? ?? 'Artista Jamendo',
      location: secured.toString(),
      source: TrackSource.online,
      providerId: id,
      originUrl: 'https://www.jamendo.com/track/$trackId',
      artworkUrl: row['image'] as String?,
      licenseUrl: row['license_ccurl'] as String?,
      color: int.parse(trackId) % 3,
      // Offline Jamendo access needs a separate review of the applicable agreement.
      downloadAllowed: false,
    );
  }

  Future<MediaCollection> search(String query, {int offset = 0}) async {
    final rows = await _get('tracks', {
      'limit': '20',
      'offset': '$offset',
      'type': 'single albumtrack',
      if (query.trim().isNotEmpty) 'search': query.trim(),
      'order': query.trim().isEmpty ? 'popularity_week' : 'relevance',
    });
    final tracks = rows
        .map((r) => _track(Map<String, dynamic>.from(r as Map)))
        .whereType<Track>()
        .toList();
    return MediaCollection(
      title: query.trim().isEmpty
          ? 'Em destaque no Jamendo'
          : 'Resultados para “${query.trim()}”',
      tracks: tracks,
      providerId: id,
      hasMore: rows.length == 20,
    );
  }

  @override
  Future<MediaCollection> resolve(Uri uri) async {
    final segments = uri.pathSegments;
    for (var i = 0; i < segments.length - 1; i++) {
      if (!['track', 'list', 'playlist'].contains(segments[i]) ||
          !RegExp(r'^\d+$').hasMatch(segments[i + 1])) {
        continue;
      }
      final trackId = segments[i + 1];
      if (segments[i] == 'track') {
        final rows = await _get('tracks', {'id': trackId});
        final tracks = rows
            .map((r) => _track(Map<String, dynamic>.from(r as Map)))
            .whereType<Track>()
            .toList();
        if (tracks.isEmpty) {
          throw const SourceException(
            'Esta faixa não está disponível no catálogo.',
          );
        }
        return MediaCollection(
          title: tracks.first.title,
          tracks: tracks,
          providerId: id,
        );
      }
      final rows = await _get('playlists/tracks', {
        'id': trackId,
        'track_type': 'single albumtrack',
      });
      if (rows.isEmpty) {
        throw const SourceException(
          'Essa playlist não foi encontrada ou não é pública.',
        );
      }
      final playlist = Map<String, dynamic>.from(rows.first as Map);
      final tracks = (playlist['tracks'] as List? ?? [])
          .map((r) => _track(Map<String, dynamic>.from(r as Map)))
          .whereType<Track>()
          .toList();
      return MediaCollection(
        title: playlist['name'] as String? ?? 'Playlist Jamendo',
        tracks: tracks,
        providerId: id,
      );
    }
    throw const SourceException(
      'Use um link de faixa ou playlist do Jamendo. Para descobrir músicas, use a busca do catálogo.',
    );
  }
}
