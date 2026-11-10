enum TrackSource { demo, local, online }

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.location,
    required this.source,
    this.color = 0,
    this.providerId = 'direct',
    this.originUrl,
    this.artworkUrl,
    this.licenseUrl,
    this.downloadAllowed = false,
  });
  final String id, title, artist, location;
  final TrackSource source;
  final int color;
  final String providerId;
  final String? originUrl, artworkUrl, licenseUrl;
  final bool downloadAllowed;
  Track asLocal(String path) => Track(
    id: id,
    title: title,
    artist: artist,
    location: path,
    source: TrackSource.local,
    color: color,
    providerId: providerId,
    originUrl: originUrl,
    artworkUrl: artworkUrl,
    licenseUrl: licenseUrl,
    downloadAllowed: downloadAllowed,
  );
  Track asOnline() => Track(
    id: id,
    title: title,
    artist: artist,
    location: originUrl ?? location,
    source: TrackSource.online,
    color: color,
    providerId: providerId,
    originUrl: originUrl,
    artworkUrl: artworkUrl,
    licenseUrl: licenseUrl,
    downloadAllowed: downloadAllowed || providerId == 'youtube',
  );
  String get sourceLabel => switch (source) {
    TrackSource.demo => 'Demo • offline',
    TrackSource.local => 'No aparelho',
    TrackSource.online =>
      providerId == 'jamendo' ? 'Jamendo • online' : 'Online',
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'location': location,
    'source': source.name,
    'color': color,
    'providerId': providerId,
    'originUrl': originUrl,
    'artworkUrl': artworkUrl,
    'licenseUrl': licenseUrl,
    'downloadAllowed': downloadAllowed,
  };
  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    location: json['location'] as String,
    source: TrackSource.values.byName(json['source'] as String),
    color: json['color'] as int? ?? 0,
    providerId: json['providerId'] as String? ?? 'direct',
    originUrl: json['originUrl'] as String?,
    artworkUrl: json['artworkUrl'] as String?,
    licenseUrl: json['licenseUrl'] as String?,
    downloadAllowed: json['downloadAllowed'] as bool? ?? false,
  );
}

class MusicPlaylist {
  MusicPlaylist({required this.id, required this.name, List<String>? trackIds})
    : trackIds = trackIds ?? [];
  final String id, name;
  final List<String> trackIds;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trackIds': trackIds,
  };
  factory MusicPlaylist.fromJson(Map<String, dynamic> json) => MusicPlaylist(
    id: json['id'] as String,
    name: json['name'] as String,
    trackIds: List<String>.from(json['trackIds'] as List),
  );
}

const demoTracks = [
  Track(
    id: 'demo-aurora',
    title: 'Aurora',
    artist: 'MusicON Lab',
    location: 'assets/audio/aurora.wav',
    source: TrackSource.demo,
    color: 0,
  ),
  Track(
    id: 'demo-orbita',
    title: 'Órbita',
    artist: 'MusicON Lab',
    location: 'assets/audio/orbita.wav',
    source: TrackSource.demo,
    color: 1,
  ),
  Track(
    id: 'demo-mare',
    title: 'Maré violeta',
    artist: 'MusicON Lab',
    location: 'assets/audio/mare.wav',
    source: TrackSource.demo,
    color: 2,
  ),
];

String? validateAudioUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return 'Use um link HTTPS direto para um arquivo de áudio.';
  }
  return null;
}

String formatTime(Duration time) =>
    '${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';
