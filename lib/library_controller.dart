import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'library_store.dart';

class LibraryController extends ChangeNotifier {
  LibraryController(this.store);
  final LibraryStore store;
  LibraryData _data = LibraryData();
  bool importing = false;
  bool ready = false;
  bool _loadFailed = false;
  String? error;
  Future<void> _saveTail = Future.value();
  List<Track> get tracks => [...demoTracks, ..._data.tracks];
  List<MusicPlaylist> get playlists => List.unmodifiable(_data.playlists);
  bool isFavorite(Track track) => _data.favorites.contains(track.id);
  List<Track> playlistTracks(MusicPlaylist playlist) => playlist.trackIds
      .expand((id) => tracks.where((t) => t.id == id))
      .toList();
  Future<void> load() async {
    try {
      _data = await store.load();
    } catch (_) {
      _loadFailed = true;
      error =
          'Não foi possível abrir a biblioteca salva. Reinicie o app para tentar novamente.';
    }
    ready = true;
    notifyListeners();
  }

  Future<bool> _save() {
    if (_loadFailed) return Future.value(false);
    var success = true;
    final snapshot = LibraryData.fromJson(_data.toJson());
    _saveTail = _saveTail.then((_) async {
      try {
        await store.save(snapshot);
      } catch (_) {
        success = false;
        error =
            'Não foi possível salvar. Suas mudanças podem não permanecer ao fechar o app.';
        notifyListeners();
      }
    });
    return _saveTail.then((_) => success);
  }

  Track? findTrack(String id) {
    for (final track in tracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  /// Keeps the same id when an online track becomes offline, preserving playlists.
  Future<Track> addResolved(Track track, {bool replaceLocal = false}) async {
    if (track.source == TrackSource.online &&
        track.providerId == 'youtube' &&
        track.originUrl != null) {
      // Persist the stable page address, never an expiring signed media URL.
      track = Track(
        id: track.id,
        title: track.title,
        artist: track.artist,
        location: track.originUrl!,
        originUrl: track.originUrl,
        source: TrackSource.online,
        providerId: 'youtube',
        artworkUrl: track.artworkUrl,
        color: track.color,
        downloadAllowed: true,
      );
    }
    if (_loadFailed) {
      throw StateError('Reabra o app para recuperar a biblioteca.');
    }
    final index = _data.tracks.indexWhere((t) => t.id == track.id);
    final previous = index < 0 ? null : _data.tracks[index];
    if (!replaceLocal &&
        previous?.source == TrackSource.local &&
        track.source == TrackSource.online) {
      return previous!;
    }
    if (index < 0) {
      _data.tracks.add(track);
    } else {
      _data.tracks[index] = track;
    }
    if (!await _save()) {
      // Only roll back this track, preserving unrelated favorites/playlist edits.
      final current = _data.tracks.indexWhere((t) => identical(t, track));
      if (current >= 0) {
        if (previous == null) {
          _data.tracks.removeAt(current);
        } else {
          _data.tracks[current] = previous;
        }
      }
      notifyListeners();
      throw StateError('Não foi possível salvar a faixa na biblioteca.');
    }
    notifyListeners();
    return track;
  }

  Future<void> toggleFavorite(Track track) async {
    if (findTrack(track.id) == null) await addResolved(track);
    if (!_data.favorites.remove(track.id)) _data.favorites.add(track.id);
    notifyListeners();
    await _save();
  }

  Future<MusicPlaylist?> createPlaylist(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return null;
    final playlist = MusicPlaylist(
      id: 'p-${DateTime.now().microsecondsSinceEpoch}',
      name: clean,
    );
    _data.playlists.add(playlist);
    notifyListeners();
    await _save();
    return playlist;
  }

  Future<MusicPlaylist> importCollection(
    String name,
    List<Track> tracks,
  ) async {
    if (_loadFailed || name.trim().isEmpty || tracks.isEmpty) {
      throw StateError('Não foi possível importar a coleção.');
    }
    final original = LibraryData.fromJson(_data.toJson());
    final playlist = MusicPlaylist(
      id: 'p-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
    );
    for (final track in tracks) {
      if (findTrack(track.id) == null) _data.tracks.add(track.asOnline());
      if (!playlist.trackIds.contains(track.id)) {
        playlist.trackIds.add(track.id);
      }
    }
    _data.playlists.add(playlist);
    if (!await _save()) {
      _data.playlists.removeWhere((p) => p.id == playlist.id);
      final oldIds = original.tracks.map((t) => t.id).toSet();
      _data.tracks.removeWhere(
        (t) =>
            tracks.any((v) => v.id == t.id) &&
            !oldIds.contains(t.id) &&
            !_data.favorites.contains(t.id) &&
            !_data.playlists.any((p) => p.trackIds.contains(t.id)),
      );
      notifyListeners();
      throw StateError('Não foi possível salvar a playlist importada.');
    }
    notifyListeners();
    return playlist;
  }

  Future<void> addToPlaylist(MusicPlaylist playlist, Track track) async {
    if (findTrack(track.id) == null) await addResolved(track);
    if (!playlist.trackIds.contains(track.id)) playlist.trackIds.add(track.id);
    notifyListeners();
    await _save();
  }

  Future<void> removeFromPlaylist(MusicPlaylist playlist, Track track) async {
    playlist.trackIds.remove(track.id);
    notifyListeners();
    await _save();
  }

  Future<Track> addOnline(String title, String artist, String url) async {
    final cleanUrl = url.trim();
    if (validateAudioUrl(cleanUrl) != null || title.trim().isEmpty) {
      throw ArgumentError('Preencha o título e um link HTTPS válido.');
    }
    final duplicate = _data.tracks.where(
      (t) => t.source == TrackSource.online && t.location == cleanUrl,
    );
    if (duplicate.isNotEmpty) return duplicate.first;
    final track = Track(
      id: 'online-${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim(),
      artist: artist.trim().isEmpty ? 'Artista independente' : artist.trim(),
      location: cleanUrl,
      source: TrackSource.online,
      color: _data.tracks.length % 3,
    );
    _data.tracks.add(track);
    notifyListeners();
    await _save();
    return track;
  }

  Future<int> importAudio() async {
    if (importing) return 0;
    importing = true;
    error = null;
    notifyListeners();
    var count = 0;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (result == null) return 0;
      final dir = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'music'),
      );
      await dir.create(recursive: true);
      var failed = 0;
      for (final selected in result.files) {
        try {
          if (selected.path == null) {
            failed++;
            continue;
          }
          final id = 'local-${DateTime.now().microsecondsSinceEpoch}-$count';
          final destination = p.join(
            dir.path,
            '$id${p.extension(selected.name)}',
          );
          await File(selected.path!).copy(destination);
          _data.tracks.add(
            Track(
              id: id,
              title: p.basenameWithoutExtension(selected.name),
              artist: 'Minha coleção',
              location: destination,
              source: TrackSource.local,
              color: _data.tracks.length % 3,
            ),
          );
          count++;
        } catch (_) {
          failed++;
        }
      }
      await _save();
      if (failed > 0) {
        error =
            '$failed arquivo(s) não puderam ser importados. Verifique o espaço disponível.';
      }
    } catch (_) {
      error = 'Não foi possível importar os arquivos. Tente novamente.';
    } finally {
      importing = false;
      notifyListeners();
    }
    return count;
  }
}
