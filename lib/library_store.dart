import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class LibraryData {
  LibraryData({
    List<Track>? tracks,
    Set<String>? favorites,
    List<MusicPlaylist>? playlists,
  }) : tracks = tracks ?? [],
       favorites = favorites ?? {},
       playlists = playlists ?? [];
  final List<Track> tracks;
  final Set<String> favorites;
  final List<MusicPlaylist> playlists;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'tracks': tracks.map((t) => t.toJson()).toList(),
    'favorites': favorites.toList(),
    'playlists': playlists.map((p) => p.toJson()).toList(),
  };
  factory LibraryData.fromJson(Map<String, dynamic> json) => LibraryData(
    tracks: (json['tracks'] as List)
        .map((t) => Track.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList(),
    favorites: Set<String>.from(json['favorites'] as List),
    playlists: (json['playlists'] as List)
        .map((p) => MusicPlaylist.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList(),
  );
}

abstract class LibraryStore {
  Future<LibraryData> load();
  Future<void> save(LibraryData data);
}

class PreferencesLibraryStore implements LibraryStore {
  static const key = 'musicon.library.v1';
  @override
  Future<LibraryData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return LibraryData();
    return LibraryData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(LibraryData data) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(data.toJson()))) {
      throw StateError('Não foi possível salvar a biblioteca.');
    }
  }
}
