import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models.dart';
import 'media_source.dart';

class AudioProbe {
  const AudioProbe({required this.uri, required this.extension, this.bytes});
  final Uri uri;
  final String extension;
  final int? bytes;
}

abstract class AudioInspector {
  Future<AudioProbe> inspect(Uri uri);
}

class DirectAudioSource implements MediaSource {
  DirectAudioSource(this.inspector);
  final AudioInspector inspector;
  @override
  String get id => 'direct';
  @override
  bool accepts(Uri uri) =>
      {LinkKind.direct, LinkKind.webpage}.contains(identifyLink(uri));
  @override
  Future<MediaCollection> resolve(Uri uri) async {
    final probe = await inspector.inspect(uri);
    final stem = uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.last.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final title = stem.isEmpty ? 'Áudio online' : stem.replaceAll('_', ' ');
    final track = Track(
      id: 'direct-${sha256.convert(utf8.encode(uri.toString()))}',
      title: title,
      artist: uri.host,
      location: uri.toString(),
      source: TrackSource.online,
      providerId: id,
      originUrl: uri.toString(),
      downloadAllowed: true,
      color: probe.extension.length % 3,
    );
    return MediaCollection(title: title, tracks: [track], providerId: id);
  }
}
