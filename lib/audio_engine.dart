import 'package:flutter/foundation.dart';
import 'models.dart';

abstract class MusicEngine extends ChangeNotifier {
  Track? get current;
  bool get playing;
  bool get busy;
  bool get hasNext;
  bool get hasPrevious;
  bool get shuffle;
  bool get repeat;
  Duration get position;
  Duration get duration;
  String? get error;
  Future<void> playQueue(List<Track> tracks, int index);
  Future<void> removeTrack(String id);
  Future<void> toggle();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  Future<void> toggleShuffle();
  Future<void> toggleRepeat();
}
