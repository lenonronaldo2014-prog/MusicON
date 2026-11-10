// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Uses Android's HTTPS stack for Spotify, independently of Dart's sockets.
class AndroidSpotifyClient extends http.BaseClient {
  static const channel = MethodChannel('musicon/spotify_http');
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('Client closed');
    final body = await request.finalize().toBytes();
    try {
      final response = await channel
          .invokeMapMethod<String, dynamic>('request', {
            'method': request.method,
            'url': request.url.toString(),
            'headers': request.headers,
            'body': body,
          });
      if (response == null) {
        throw http.ClientException('Empty Android response');
      }
      final bytes = response['body'] as Uint8List;
      return http.StreamedResponse(
        Stream.value(bytes),
        response['status'] as int,
        headers: Map<String, String>.from(response['headers'] as Map),
        contentLength: bytes.length,
        request: request,
      );
    } on PlatformException catch (error) {
      switch (error.code) {
        case 'dns':
          throw SocketException("Failed host lookup: '${request.url.host}'");
        case 'timeout':
          throw TimeoutException('Spotify connection timeout');
        case 'tls':
          throw const HandshakeException('Spotify secure connection failed');
        default:
          // Never forward native exception text, URLs, request bodies or tokens.
          throw http.ClientException('Spotify connection failed');
      }
    }
  }

  @override
  void close() => _closed = true;
}
