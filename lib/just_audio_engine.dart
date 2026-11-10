import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'audio_engine.dart';
import 'models.dart';

class JustAudioEngine extends MusicEngine {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<Track> _queue = [];
  String? _error;
  bool _loading = false;
  bool _disposed = false;
  final AudioSource Function(Track track, MediaItem tag)? onlineSourceFactory;
  JustAudioEngine({this.onlineSourceFactory}) {
    _subscriptions.addAll([
      _player.playerStateStream.listen((_) => _changed()),
      _player.positionStream.listen((_) => _changed()),
      _player.durationStream.listen((_) => _changed()),
      _player.currentIndexStream.listen((_) => _changed()),
      _player.shuffleModeEnabledStream.listen((_) => _changed()),
      _player.loopModeStream.listen((_) => _changed()),
      _player.errorStream.listen((_) => _fail()),
    ]);
  }
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _fail() {
    _error =
        'Não foi possível tocar esta faixa. Verifique a conexão ou o arquivo e tente novamente.';
    _changed();
  }

  @override
  Track? get current {
    final i = _player.currentIndex;
    return i != null && i >= 0 && i < _queue.length ? _queue[i] : null;
  }

  @override
  bool get playing =>
      _player.playing && _player.processingState != ProcessingState.completed;
  @override
  bool get busy =>
      _loading ||
      _player.processingState == ProcessingState.loading ||
      _player.processingState == ProcessingState.buffering;
  @override
  bool get hasNext => _player.hasNext;
  @override
  bool get hasPrevious => _player.hasPrevious || position.inSeconds > 2;
  @override
  bool get shuffle => _player.shuffleModeEnabled;
  @override
  bool get repeat => _player.loopMode == LoopMode.all;
  @override
  Duration get position => _player.position;
  @override
  Duration get duration => _player.duration ?? Duration.zero;
  @override
  String? get error => _error;
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on PlayerInterruptedException {
      /* Superseded load. */
    } catch (_) {
      _fail();
    }
  }

  @override
  Future<void> playQueue(List<Track> tracks, int index) async {
    if (_loading || tracks.isEmpty || index < 0 || index >= tracks.length) {
      return;
    }
    _loading = true;
    _error = null;
    _changed();
    try {
      await _player.pause();
      _queue = List.of(tracks);
      final sources = _queue.map((t) {
        final tag = MediaItem(
          id: t.id,
          title: t.title,
          artist: t.artist,
          album: 'MusicON',
          artUri: t.artworkUrl?.startsWith('https://') == true
              ? Uri.tryParse(t.artworkUrl!)
              : null,
        );
        return switch (t.source) {
          TrackSource.demo => AudioSource.asset(t.location, tag: tag),
          TrackSource.local => AudioSource.file(t.location, tag: tag),
          TrackSource.online =>
            onlineSourceFactory?.call(t, tag) ??
                AudioSource.uri(Uri.parse(t.location), tag: tag),
        };
      }).toList();
      await _player.setAudioSources(sources, initialIndex: index);
      unawaited(_guard(_player.play));
    } on PlayerInterruptedException {
      /* A newer source replaced this load. */
    } catch (_) {
      _fail();
    } finally {
      _loading = false;
      _changed();
    }
  }

  @override
  Future<void> toggle() => _guard(() async {
    if (playing) {
      await _player.pause();
      return;
    }
    _error = null;
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    unawaited(_guard(_player.play));
  });
  @override
  Future<void> seek(Duration position) => _guard(() => _player.seek(position));
  @override
  Future<void> next() => _guard(() async {
    if (hasNext) await _player.seekToNext();
  });
  @override
  Future<void> previous() => _guard(() async {
    if (position.inSeconds > 2) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  });
  @override
  Future<void> toggleShuffle() => _guard(() async {
    if (!shuffle) await _player.shuffle();
    await _player.setShuffleModeEnabled(!shuffle);
  });
  @override
  Future<void> toggleRepeat() =>
      _guard(() => _player.setLoopMode(repeat ? LoopMode.off : LoopMode.all));
  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}
