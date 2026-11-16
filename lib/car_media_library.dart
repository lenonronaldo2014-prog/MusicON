import 'package:audio_service/audio_service.dart';
import 'library_controller.dart';
import 'models.dart';

/// Stable identifiers preserve the selected album/list when the car starts playback.
class CarMediaLibrary {
  CarMediaLibrary(this.library);
  final LibraryController library;

  static MediaItem folder(String id, String title) =>
      MediaItem(id: id, title: title, playable: false);

  static MediaItem item(Track track, {String? parent, Duration? duration}) =>
      MediaItem(
        id: parent == null
            ? track.id
            : Uri(pathSegments: ['track', parent, track.id]).toString(),
        title: track.title,
        artist: track.artist,
        album: 'MusicON',
        duration: duration,
        artUri: track.artworkUrl?.startsWith('https://') == true
            ? Uri.tryParse(track.artworkUrl!)
            : null,
        playable: true,
      );

  List<Track> tracks(String parent) => switch (parent) {
    'all' => library.tracks,
    'favorites' => library.tracks.where(library.isFavorite).toList(),
    'offline' =>
      library.tracks.where((t) => t.source != TrackSource.online).toList(),
    _ => [
      for (final playlist in library.playlists)
        if (parent == 'playlist/${playlist.id}')
          ...library.playlistTracks(playlist),
    ],
  };

  List<MediaItem> children(String parent) {
    if (parent == AudioService.browsableRootId) {
      return [
        folder('all', 'Todas as músicas'),
        folder('favorites', 'Favoritos'),
        folder('offline', 'No aparelho'),
        folder('playlists', 'Playlists'),
      ];
    }
    if (parent == 'playlists') {
      return [
        for (final p in library.playlists) folder('playlist/${p.id}', p.name),
      ];
    }
    return [for (final track in tracks(parent)) item(track, parent: parent)];
  }

  ({List<Track> tracks, int index})? resolve(String mediaId) {
    try {
      final parts = Uri.parse(mediaId).pathSegments;
      if (parts.length == 3 && parts.first == 'track') {
        final list = tracks(parts[1]);
        final index = list.indexWhere((t) => t.id == parts[2]);
        return index < 0 ? null : (tracks: list, index: index);
      }
    } on FormatException {
      return null;
    }
    final all = library.tracks;
    final index = all.indexWhere((t) => t.id == mediaId);
    return index < 0 ? null : (tracks: all, index: index);
  }

  List<Track> searchTracks(String query) {
    final terms = query.toLowerCase().trim();
    return library.tracks
        .where((t) => '${t.title} ${t.artist}'.toLowerCase().contains(terms))
        .toList();
  }
}
