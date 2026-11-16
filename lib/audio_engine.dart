import 'package:flutter/foundation.dart';
import 'models.dart';

enum MusicProcessingState { idle, loading, buffering, ready, completed }

abstract class MusicEngine extends ChangeNotifier {
  Listenable get playbackChanges => this;
  List<Track> get queueTracks;
  int? get queueIndex;
  MusicProcessingState get processingState;
  Track? get current;
  bool get playing;
  bool get busy;
  bool get hasNext;
  bool get hasPrevious;
  bool get shuffle;
  bool get repeat;
  double get volume;
  Duration get position;
  Duration get duration;
  String? get error;
  Future<void> playQueue(List<Track> tracks, int index);
  Future<void> removeTrack(String id);
  Future<void> toggle();
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> skipToIndex(int index);
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> next();
  Future<void> previous();
  Future<void> toggleShuffle();
  Future<void> toggleRepeat();
}
