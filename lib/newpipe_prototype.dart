// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'newpipe_audio_source.dart';
import 'music_discovery_view.dart';
import 'audio_engine.dart';
import 'downloads/audio_network.dart';
import 'models.dart';
import 'ui.dart' show musicTheme;

class VideoResult {
  const VideoResult({
    required this.title,
    required this.artist,
    required this.url,
    this.artwork,
  });
  final String title, artist, url;
  final String? artwork;
  factory VideoResult.fromMap(Map<Object?, Object?> value) => VideoResult(
    title: value['title'] as String? ?? 'Sem título',
    artist: value['artist'] as String? ?? 'YouTube',
    url: value['url'] as String,
    artwork: value['artwork'] as String?,
  );
}

class NewPipeSource {
  NewPipeSource({this.channel = const MethodChannel('musicon/newpipe')});
  final MethodChannel channel;
  Map<String, String> _headers = {};
  AudioSource audioSource(Track track, MediaItem tag) =>
      track.providerId == 'youtube'
      ? (track.location == track.originUrl
            ? DeferredNewPipeAudioSource(() async {
                final resolved = await _resolve(track.originUrl!);
                return NewPipeAudioSource(
                  Uri.parse(resolved.track.location),
                  headers: resolved.headers,
                  tag: tag,
                );
              }, tag: tag)
            : NewPipeAudioSource(
                Uri.parse(track.location),
                headers: Map.of(_headers),
                tag: tag,
              ))
      : AudioSource.uri(Uri.parse(track.location), tag: tag);
  Future<List<VideoResult>> search(String query) async {
    final items = await channel
        .invokeListMethod<Object?>('search', {'value': query.trim()})
        .timeout(const Duration(seconds: 60));
    return (items ?? [])
        .map((item) => VideoResult.fromMap(item as Map<Object?, Object?>))
        .toList();
  }

  Future<Track> resolve(String url) async {
    final resolved = await _resolve(url);
    _headers = resolved.headers;
    return resolved.track;
  }

  Future<AudioResponse> openDownload(Track track, Cancellation cancel) async {
    cancel.check();
    final resolved = await _resolve(track.originUrl ?? track.location);
    cancel.check();
    final audio = await NewPipeAudioSource(
      Uri.parse(resolved.track.location),
      headers: resolved.headers,
      cancellation: cancel,
    ).request();
    return AudioResponse(
      uri: Uri.parse(resolved.track.location),
      status: 200,
      contentType: audio.contentType,
      length: audio.sourceLength ?? audio.contentLength,
      stream: audio.stream,
      close: cancel.cancel,
    );
  }

  Future<({Track track, Map<String, String> headers})> _resolve(
    String url,
  ) async {
    final data = await channel
        .invokeMapMethod<Object?, Object?>('resolve', {'value': url})
        .timeout(const Duration(seconds: 60));
    if (data == null) throw StateError('Resposta vazia da fonte.');
    final stream = Uri.tryParse(data['stream'] as String? ?? '');
    if (stream == null ||
        stream.scheme != 'https' ||
        stream.host.isEmpty ||
        stream.userInfo.isNotEmpty) {
      throw StateError('A fonte não forneceu um endereço de áudio compatível.');
    }
    final headers = Map<String, String>.from(data['headers'] as Map? ?? {});
    return (
      headers: headers,
      track: Track(
        id: 'youtube-${data['url']}',
        title: data['title'] as String,
        artist: data['artist'] as String? ?? 'YouTube',
        location: stream.toString(),
        source: TrackSource.online,
        providerId: 'youtube',
        originUrl: data['url'] as String,
        artworkUrl: data['artwork'] as String?,
        downloadAllowed: true,
      ),
    );
  }
}

class PrototypeController extends ChangeNotifier {
  PrototypeController(this.source, this.engine);
  final NewPipeSource source;
  final MusicEngine engine;
  List<VideoResult> results = [];
  bool searching = false, resolving = false, disposed = false;
  String? error;
  int _request = 0;
  void _changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty || searching || resolving) return;
    if (query.trim().startsWith('https://')) {
      await play(
        VideoResult(title: 'Link do YouTube', artist: '', url: query.trim()),
      );
      return;
    }
    final request = ++_request;
    searching = true;
    error = null;
    results = [];
    _changed();
    try {
      final items = await source.search(query);
      if (disposed || request != _request) return;
      results = items;
    } catch (e) {
      if (!disposed && request == _request) error = _message(e);
    } finally {
      if (!disposed && request == _request) {
        searching = false;
        _changed();
      }
    }
  }

  Future<void> play(VideoResult video) async {
    if (resolving || searching) return;
    final request = ++_request;
    resolving = true;
    error = null;
    _changed();
    try {
      // Resolve on every play; temporary media addresses never go into the saved library.
      final track = await source.resolve(video.url);
      if (disposed || request != _request) return;
      results = [
        VideoResult(
          title: track.title,
          artist: track.artist,
          url: track.originUrl!,
          artwork: track.artworkUrl,
        ),
      ];
      await engine.playQueue([track], 0);
      if (engine.error != null) error = engine.error;
    } catch (e) {
      if (!disposed && request == _request) error = _message(e);
    } finally {
      if (!disposed && request == _request) {
        resolving = false;
        _changed();
      }
    }
  }

  String _message(Object e) => switch (e) {
    PlatformException() => e.message ?? 'Falha no extrator.',
    TimeoutException() => 'A fonte demorou para responder. Tente novamente.',
    MissingPluginException() =>
      'Este protótipo precisa ser executado no Android.',
    _ => 'Não foi possível preparar o áudio. Tente outra faixa.',
  };
  @override
  void dispose() {
    disposed = true;
    _request++;
    super.dispose();
  }
}

class NewPipePrototype extends StatefulWidget {
  const NewPipePrototype({super.key, required this.controller});
  final PrototypeController controller;
  @override
  State<NewPipePrototype> createState() => _NewPipePrototypeState();
}

class _NewPipePrototypeState extends State<NewPipePrototype> {
  final input = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: musicTheme,
    home: AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        widget.controller.engine,
      ]),
      builder: (context, _) => MusicDiscoveryView(
        state: widget.controller,
        input: input,
        scroll: scroll,
      ),
    ),
  );
}
