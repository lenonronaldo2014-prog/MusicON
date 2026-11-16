import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'audio_engine.dart';
import 'car_media_library.dart';
import 'library_controller.dart';
import 'models.dart';

/// The phone, notification and Android Auto all control the same engine.
class MusicAudioHandler extends BaseAudioHandler {
  MusicAudioHandler(this.engine, this.library)
    : catalog = CarMediaLibrary(library) {
    engine.playbackChanges.addListener(_publish);
    library.addListener(_libraryChanged);
    _publish();
  }
  final MusicEngine engine;
  final LibraryController library;
  final CarMediaLibrary catalog;
  final Map<String, BehaviorSubject<Map<String, dynamic>>> _children = {};
  List<Track> _lastQueue = [];

  void _libraryChanged() {
    for (final subject in _children.values) {
      subject.add(<String, dynamic>{});
    }
  }

  void _publish() {
    final tracks = engine.queueTracks;
    if (!listEquals(_lastQueue, tracks)) {
      _lastQueue = List.of(tracks);
      queue.add(tracks.map((t) => CarMediaLibrary.item(t)).toList());
    }
    final track = engine.current;
    if (track != null) {
      final current = CarMediaLibrary.item(track, duration: engine.duration);
      if (mediaItem.value?.id != current.id ||
          mediaItem.value?.duration != current.duration) {
        mediaItem.add(current);
        final index = engine.queueIndex;
        if (index != null && index >= 0 && index < queue.value.length) {
          final updated = List<MediaItem>.of(queue.value);
          updated[index] = current;
          queue.add(updated);
        }
      }
    }
    final controls = [
      MediaControl.skipToPrevious,
      if (engine.playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.stop,
    ];
    playbackState.add(
      PlaybackState(
        controls: controls,
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {
          MediaAction.seek,
          MediaAction.playFromMediaId,
          MediaAction.playFromSearch,
          MediaAction.skipToQueueItem,
        },
        processingState: engine.error != null
            ? AudioProcessingState.error
            : switch (engine.processingState) {
                MusicProcessingState.idle => AudioProcessingState.idle,
                MusicProcessingState.loading => AudioProcessingState.loading,
                MusicProcessingState.buffering =>
                  AudioProcessingState.buffering,
                MusicProcessingState.ready => AudioProcessingState.ready,
                MusicProcessingState.completed =>
                  AudioProcessingState.completed,
              },
        playing: engine.playing,
        updatePosition: engine.position,
        queueIndex: engine.queueIndex,
        repeatMode: engine.repeat
            ? AudioServiceRepeatMode.all
            : AudioServiceRepeatMode.none,
        shuffleMode: engine.shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        errorCode: engine.error == null ? null : 1,
        errorMessage: engine.error,
      ),
    );
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    if (parentMediaId == AudioService.recentRootId) {
      final track = engine.current;
      return track == null ? [] : [CarMediaLibrary.item(track)];
    }
    return catalog.children(parentMediaId);
  }

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) =>
      _children.putIfAbsent(
        parentMediaId,
        () => BehaviorSubject.seeded(<String, dynamic>{}),
      );

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final resolved = catalog.resolve(mediaId);
    return resolved == null
        ? null
        : CarMediaLibrary.item(resolved.tracks[resolved.index]);
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final resolved = catalog.resolve(mediaId);
    if (resolved != null) {
      await engine.playQueue(resolved.tracks, resolved.index);
    }
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async =>
      catalog.searchTracks(query).map((t) => CarMediaLibrary.item(t)).toList();

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final matches = catalog.searchTracks(query);
    if (matches.isNotEmpty) await engine.playQueue(matches, 0);
  }

  @override
  Future<void> play() async {
    if (engine.current == null) {
      final tracks = library.tracks;
      if (tracks.isNotEmpty) await engine.playQueue(tracks, 0);
    } else {
      await engine.play();
    }
  }

  @override
  Future<void> pause() => engine.pause();
  @override
  Future<void> stop() => engine.stop();
  @override
  Future<void> seek(Duration position) => engine.seek(position);
  @override
  Future<void> skipToNext() => engine.next();
  @override
  Future<void> skipToPrevious() => engine.previous();
  @override
  Future<void> skipToQueueItem(int index) => engine.skipToIndex(index);
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (engine.repeat !=
        (repeatMode == AudioServiceRepeatMode.all ||
            repeatMode == AudioServiceRepeatMode.group)) {
      await engine.toggleRepeat();
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (engine.shuffle != (shuffleMode != AudioServiceShuffleMode.none)) {
      await engine.toggleShuffle();
    }
  }

  Future<void> dispose() async {
    engine.playbackChanges.removeListener(_publish);
    library.removeListener(_libraryChanged);
    for (final subject in _children.values) {
      await subject.close();
    }
  }
}
