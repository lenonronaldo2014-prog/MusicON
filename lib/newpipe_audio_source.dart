// SPDX-License-Identifier: GPL-3.0-or-later
// Intentional experimental API, isolated to this prototype and pinned just_audio version.
// ignore_for_file: experimental_member_use
// Transport follows NewPipe's YoutubeHttpDataSource protocol (POST and byte ranges).
// https://github.com/TeamNewPipe/NewPipe/blob/dev/app/src/main/java/org/schabi/newpipe/player/datasource/YoutubeHttpDataSource.java
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'downloads/audio_network.dart';

class NewPipeAudioSource extends StreamAudioSource {
  NewPipeAudioSource(
    this.uri, {
    required this.headers,
    super.tag,
    this.cancellation,
  });
  final Cancellation? cancellation;
  final Uri uri;
  final Map<String, String> headers;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    if (uri.scheme != 'https' || !uri.host.endsWith('.googlevideo.com')) {
      throw StateError('Fonte de áudio incompatível com este protótipo.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..autoUncompress = false;
    void close() {
      client.close(force: true);
      cancellation?.detach(close);
    }

    cancellation?.attach(close);
    cancellation?.check();
    final offset = start ?? 0;
    final total = int.tryParse(uri.queryParameters['clen'] ?? '');
    var target = Uri.parse('$uri&range=$offset-${end == null ? '' : end - 1}');
    try {
      for (var redirects = 0; redirects < 5; redirects++) {
        if (target.scheme != 'https' ||
            !target.host.endsWith('.googlevideo.com')) {
          throw StateError('Redirecionamento de áudio incompatível.');
        }
        final request = await client.postUrl(target);
        request.followRedirects = false;
        headers.forEach(request.headers.set);
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        request.headers.set('TE', 'trailers');
        request.contentLength = 2;
        request.add([0x78, 0]);
        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.listen((_) {}).cancel();
          if (location == null) {
            throw const HttpException('Redirecionamento incompleto');
          }
          target = target.resolve(location);
          continue;
        }
        if (response.statusCode != 200 && response.statusCode != 206) {
          debugPrint('MUSICON_MEDIA HTTP ${response.statusCode}');
          throw HttpException(
            'Servidor recusou o áudio (HTTP ${response.statusCode}).',
          );
        }
        cancellation?.check();
        final length = response.contentLength >= 0
            ? response.contentLength
            : null;
        return StreamAudioResponse(
          sourceLength: total,
          contentLength: length,
          offset: start == null ? null : offset,
          rangeRequestsSupported: total != null,
          contentType: response.headers.contentType?.mimeType ?? 'audio/webm',
          stream: _read(response, close),
        );
      }
      throw const HttpException('Redirecionamentos em excesso');
    } catch (_) {
      close();
      rethrow;
    }
  }

  Stream<List<int>> _read(
    HttpClientResponse response,
    void Function() close,
  ) async* {
    try {
      await for (final chunk in response.timeout(const Duration(seconds: 25))) {
        cancellation?.check();
        yield chunk;
      }
    } finally {
      close();
    }
  }
}

/// Resolves each queued item only when the player requests its audio.
/// A fresh queue gets fresh signed URLs; saved library data contains page URLs only.
class DeferredNewPipeAudioSource extends StreamAudioSource {
  DeferredNewPipeAudioSource(this.resolve, {super.tag});
  final Future<NewPipeAudioSource> Function() resolve;
  Future<NewPipeAudioSource>? _pending;
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      final source = await (_pending ??= resolve());
      return await source.request(start, end);
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }
}
