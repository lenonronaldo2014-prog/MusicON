import '../models.dart';

class SourceException implements Exception {
  const SourceException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum LinkKind { direct, jamendo, youtube, spotify, webpage }

bool hostMatches(String host, String domain) =>
    host == domain || host.endsWith('.$domain');

Uri parseWebLink(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const SourceException(
      'Cole um link HTTPS válido, sem usuário ou senha no endereço.',
    );
  }
  return uri;
}

const audioExtensions = {'mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus', 'flac'};
String audioExtension(Uri uri) => uri.pathSegments.isEmpty
    ? ''
    : uri.pathSegments.last.split('.').last.toLowerCase();

LinkKind identifyLink(Uri uri) {
  final host = uri.host.toLowerCase();
  if (hostMatches(host, 'youtube.com') || host == 'youtu.be') {
    return LinkKind.youtube;
  }
  if (hostMatches(host, 'spotify.com') || host == 'spotify.link') {
    return LinkKind.spotify;
  }
  if (hostMatches(host, 'jamendo.com')) return LinkKind.jamendo;
  return audioExtensions.contains(audioExtension(uri))
      ? LinkKind.direct
      : LinkKind.webpage;
}

class MediaCollection {
  const MediaCollection({
    required this.title,
    required this.tracks,
    required this.providerId,
    this.hasMore = false,
  });
  final String title, providerId;
  final List<Track> tracks;
  final bool hasMore;
}

abstract class MediaSource {
  String get id;
  bool accepts(Uri uri);
  Future<MediaCollection> resolve(Uri uri);
}

class SourceRegistry {
  SourceRegistry(this.sources);
  final List<MediaSource> sources;
  Future<MediaCollection> resolve(String input) async {
    final uri = parseWebLink(input);
    switch (identifyLink(uri)) {
      case LinkKind.youtube:
        throw const SourceException(
          'Este é um link do YouTube. Abra no navegador do MusicON para usar o player do site. A extração de áudio não está implementada.',
        );
      case LinkKind.spotify:
        throw const SourceException(
          'Este link identifica conteúdo do Spotify, não um arquivo de áudio. A reprodução independente do Spotify não está disponível.',
        );
      default:
        break;
    }
    for (final source in sources) {
      if (source.accepts(uri)) return source.resolve(uri);
    }
    throw const SourceException('Nenhuma fonte compatível com esse link.');
  }
}
