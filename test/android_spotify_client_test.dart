import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicon/spotify/android_spotify_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () =>
        messenger.setMockMethodCallHandler(AndroidSpotifyClient.channel, null),
  );

  test(
    'native transport preserves form encoding and HTTP error responses',
    () async {
      messenger.setMockMethodCallHandler(AndroidSpotifyClient.channel, (
        call,
      ) async {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        expect(args['method'], 'POST');
        expect(args['url'], 'https://accounts.spotify.com/api/token');
        final body = Uri.splitQueryString(
          utf8.decode(args['body'] as Uint8List),
        );
        expect(body['code'], 'test+code/&');
        expect(body['code_verifier'], 'test-verifier');
        expect(
          (args['headers'] as Map)['content-type'],
          contains('application/x-www-form-urlencoded'),
        );
        return {
          'status': 400,
          'headers': {'content-type': 'application/json'},
          'body': Uint8List.fromList(utf8.encode('{"error":"invalid_grant"}')),
        };
      });
      final client = AndroidSpotifyClient();
      final response = await client.post(
        Uri.https('accounts.spotify.com', '/api/token'),
        body: {'code': 'test+code/&', 'code_verifier': 'test-verifier'},
      );
      expect(response.statusCode, 400);
      expect(jsonDecode(response.body)['error'], 'invalid_grant');
      client.close();
    },
  );

  test(
    'DNS, timeout and TLS classifications contain no native credentials',
    () async {
      final expected = <String, Matcher>{
        'dns': isA<SocketException>(),
        'timeout': isA<TimeoutException>(),
        'tls': isA<HandshakeException>(),
        'network': isA<Exception>(),
      };
      for (final entry in expected.entries) {
        messenger.setMockMethodCallHandler(AndroidSpotifyClient.channel, (
          _,
        ) async {
          throw PlatformException(
            code: entry.key,
            message: 'private-test-credential',
          );
        });
        final client = AndroidSpotifyClient();
        await expectLater(
          client.get(Uri.https('api.spotify.com', '/v1/me/playlists')),
          throwsA(
            allOf(
              entry.value,
              predicate<Object>(
                (error) =>
                    !error.toString().contains('private-test-credential'),
              ),
            ),
          ),
        );
        client.close();
      }
    },
  );
}
