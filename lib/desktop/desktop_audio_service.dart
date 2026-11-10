// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../device_audio_service.dart';
import '../models.dart';
import 'windows_files.dart';

class DesktopAudioService implements FolderAudioService {
  DesktopAudioService({this.folders}) {
    _changes = StreamController<void>.broadcast(onCancel: _stopWatching);
  }
  late final StreamController<void> _changes;
  final _watchers = <StreamSubscription<FileSystemEvent>>[];
  List<String> _roots = [];
  final Future<List<String>> Function()? folders;
  static const extensions = {
    '.mp3',
    '.m4a',
    '.aac',
    '.wav',
    '.flac',
    '.ogg',
    '.opus',
    '.wma',
    '.aiff',
    '.webm',
  };
  @override
  Stream<void> get changes => _changes.stream;
  Future<List<String>> _folders() async {
    if (folders != null) return folders!();
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList('musicon.desktopMusicFolders');
    if (custom != null) return custom;
    final home = Platform.environment['USERPROFILE'];
    if (home == null) return [];
    final music = Directory(p.join(home, 'Music'));
    return await music.exists() ? [music.path] : [];
  }

  @override
  Future<bool> addFolder() async {
    final chosen = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Adicionar pasta de músicas',
    );
    if (chosen == null) return false;
    final roots = await _folders();
    final folder = p.normalize(p.absolute(chosen));
    if (!roots.any((root) => p.equals(root, folder))) roots.add(folder);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('musicon.desktopMusicFolders', roots);
    return true;
  }

  void _stopWatching() {
    for (final watcher in _watchers) {
      unawaited(watcher.cancel());
    }
    _watchers.clear();
  }

  @override
  Future<DeviceAudioSnapshot> scan({required bool requestPermission}) async {
    _roots = await _folders();
    _stopWatching();
    final tracks = <String, Track>{};
    for (final root in _roots) {
      final directory = Directory(root);
      if (!await directory.exists()) {
        throw FileSystemException(
          'Pasta indisponível. Reconecte a unidade.',
          root,
        );
      }
      try {
        _watchers.add(
          directory
              .watch(recursive: true)
              .listen((_) => _changes.add(null), onError: (Object _) {}),
        );
      } catch (_) {
        /* Manual refresh remains available. */
      }
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File ||
            !extensions.contains(p.extension(entity.path).toLowerCase())) {
          continue;
        }
        final path = p.normalize(p.absolute(entity.path));
        final id = 'device-${sha256.convert(utf8.encode(path.toLowerCase()))}';
        final name = p.basenameWithoutExtension(path);
        final split = name.indexOf(' - ');
        tracks[id] = Track(
          id: id,
          title: split < 0 ? name : name.substring(split + 3),
          artist: split < 0 ? 'Arquivo local' : name.substring(0, split),
          location: path,
          source: TrackSource.local,
          providerId: 'device',
        );
      }
    }
    final sorted = tracks.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return DeviceAudioSnapshot(true, sorted);
  }

  @override
  Future<bool> delete(Track track) async {
    final path = p.normalize(p.absolute(track.location));
    final roots = await _folders();
    if (!roots.any((root) => p.isWithin(root, path)) ||
        !extensions.contains(p.extension(path).toLowerCase())) {
      throw StateError('Arquivo fora das pastas de músicas.');
    }
    if (!await File(path).exists()) return true;
    final actual = await File(path).resolveSymbolicLinks();
    var allowed = false;
    for (final root in roots) {
      final canonical = await Directory(root).resolveSymbolicLinks();
      if (p.isWithin(canonical, actual)) allowed = true;
    }
    if (!allowed) throw StateError('Arquivo fora das pastas de músicas.');
    return recycleMusicFile(path);
  }

  @override
  Future<void> openSettings() async {
    await addFolder();
  }
}
