import 'dart:async';
import 'dart:io';
import '../sources/direct_source.dart';
import '../sources/media_source.dart';

class TransferCancelled implements Exception {}

class Cancellation {
  bool cancelled = false;
  final List<void Function()> _callbacks = [];
  void check() {
    if (cancelled) throw TransferCancelled();
  }

  void attach(void Function() callback) {
    if (cancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
  }

  void detach(void Function() callback) => _callbacks.remove(callback);
  void cancel() {
    cancelled = true;
    for (final callback in List.of(_callbacks)) {
      callback();
    }
    _callbacks.clear();
  }
}

class AudioResponse {
  AudioResponse({
    required this.uri,
    required this.status,
    required this.contentType,
    required this.stream,
    required this.close,
    this.length,
  });
  final Uri uri;
  final int status;
  final String contentType;
  final int? length;
  final Stream<List<int>> stream;
  final void Function() close;
}

abstract class TransferClient {
  Future<AudioResponse> open(
    Uri uri,
    Cancellation cancel, {
    bool probe = false,
  });
}

class HttpTransferClient implements TransferClient {
  @override
  Future<AudioResponse> open(
    Uri uri,
    Cancellation cancel, {
    bool probe = false,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    void close() {
      client.close(force: true);
      cancel.detach(close);
    }

    cancel.attach(close);
    try {
      for (var redirect = 0; redirect <= 5; redirect++) {
        cancel.check();
        parseWebLink(uri.toString());
        if ({
          LinkKind.youtube,
          LinkKind.spotify,
          LinkKind.jamendo,
        }.contains(identifyLink(uri))) {
          throw const SourceException(
            'O endereço leva a uma página de serviço, não a um arquivo direto.',
          );
        }
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 20));
        request.followRedirects = false;
        request.headers.set(HttpHeaders.userAgentHeader, 'MusicON/0.2');
        if (probe) request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-4095');
        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        cancel.check();
        if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
          final next = response.headers.value(HttpHeaders.locationHeader);
          final subscription = response.listen((_) {});
          await subscription.cancel();
          if (next == null || redirect == 5) {
            throw const SourceException(
              'O link redireciona muitas vezes ou está incompleto.',
            );
          }
          uri = uri.resolve(next);
          continue;
        }
        if (response.statusCode != 200 &&
            !(probe && response.statusCode == 206)) {
          throw SourceException(
            'O servidor não forneceu o áudio (HTTP ${response.statusCode}).',
          );
        }
        return AudioResponse(
          uri: uri,
          status: response.statusCode,
          contentType: response.headers.contentType?.mimeType ?? '',
          length: response.contentLength < 0 ? null : response.contentLength,
          stream: response.timeout(const Duration(seconds: 25)),
          close: close,
        );
      }
      throw const SourceException('Não foi possível seguir esse link.');
    } catch (_) {
      close();
      cancel.check();
      rethrow;
    }
  }
}

String detectAudio(List<int> bytes, String contentType) {
  bool starts(List<int> pattern, [int offset = 0]) =>
      bytes.length >= offset + pattern.length &&
      List.generate(
        pattern.length,
        (i) => bytes[i + offset] == pattern[i],
      ).every((b) => b);
  final leading = String.fromCharCodes(
    bytes.take(100),
  ).trimLeft().toLowerCase();
  if (contentType.contains('html') ||
      leading.startsWith('<') ||
      leading.startsWith('{')) {
    throw const SourceException(
      'Esse endereço retornou uma página, não um arquivo de áudio. Use o navegador ou cole o link direto.',
    );
  }
  if (starts([0x1a, 0x45, 0xdf, 0xa3]) && contentType.startsWith('audio/')) {
    return 'webm';
  }
  if (starts([73, 68, 51])) return 'mp3'; // ID3
  if (starts([102, 76, 97, 67])) return 'flac';
  if (starts([79, 103, 103, 83])) return 'ogg';
  if (starts([82, 73, 70, 70]) && starts([87, 65, 86, 69], 8)) return 'wav';
  if (starts([102, 116, 121, 112], 4) && !contentType.startsWith('video/')) {
    return 'm4a';
  }
  if (bytes.length >= 2 && bytes[0] == 255 && (bytes[1] & 0xe0) == 0xe0) {
    return (bytes[1] & 0xf6) == 0xf0 ? 'aac' : 'mp3';
  }
  throw const SourceException(
    'Não foi reconhecido um áudio compatível (MP3, M4A, AAC, WAV, OGG ou FLAC).',
  );
}

class NetworkAudioInspector implements AudioInspector {
  NetworkAudioInspector(this.client);
  final TransferClient client;
  @override
  Future<AudioProbe> inspect(Uri uri) async {
    final cancel = Cancellation();
    AudioResponse? response;
    try {
      response = await client.open(uri, cancel, probe: true);
      final prefix = <int>[];
      await for (final chunk in response.stream) {
        prefix.addAll(chunk.take(4096 - prefix.length));
        if (prefix.length >= 16) break;
      }
      return AudioProbe(
        uri: response.uri,
        extension: detectAudio(prefix, response.contentType),
        bytes: response.length,
      );
    } on SourceException {
      rethrow;
    } catch (_) {
      throw const SourceException(
        'Não foi possível verificar o áudio. Confira o link e a conexão.',
      );
    } finally {
      response?.close();
    }
  }
}
