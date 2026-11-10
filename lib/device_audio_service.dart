import 'package:flutter/services.dart';
import 'models.dart';

class DeviceAudioSnapshot {
  const DeviceAudioSnapshot(this.authorized, this.tracks);
  final bool authorized;
  final List<Track> tracks;
}

abstract class DeviceAudioService {
  Stream<void> get changes;
  Future<DeviceAudioSnapshot> scan({required bool requestPermission});
  Future<bool> delete(Track track);
  Future<void> openSettings();
}

class AndroidDeviceAudioService implements DeviceAudioService {
  static const channel = MethodChannel('musicon/device_audio');
  static const events = EventChannel('musicon/device_audio_changes');
  @override
  Stream<void> get changes => events.receiveBroadcastStream().map((_) {});
  @override
  Future<DeviceAudioSnapshot> scan({required bool requestPermission}) async {
    final data = await channel.invokeMapMethod<String, dynamic>('scan', {
      'requestPermission': requestPermission,
    });
    return DeviceAudioSnapshot(
      data?['authorized'] == true,
      (data?['tracks'] as List? ?? []).map((value) {
        final row = Map<String, dynamic>.from(value as Map);
        final uri = Uri.tryParse(row['uri'] as String? ?? '');
        if (uri == null ||
            uri.scheme != 'content' ||
            uri.host != 'media' ||
            !RegExp(r'^/[A-Za-z0-9_-]+/audio/media/[0-9]+$').hasMatch(uri.path)) {
          throw StateError('Endereço de áudio local inválido.');
        }
        return Track(
          id: row['id'] as String,
          title: row['title'] as String,
          artist: row['artist'] as String,
          location: uri.toString(),
          source: TrackSource.local,
          providerId: 'device',
        );
      }).toList(),
    );
  }

  @override
  Future<bool> delete(Track track) async =>
      await channel.invokeMethod<bool>('delete', {'uri': track.location}) ??
      false;
  @override
  Future<void> openSettings() => channel.invokeMethod<void>('openSettings');
}
