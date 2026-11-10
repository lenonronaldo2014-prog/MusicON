import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musicon/device_audio_service.dart';
import 'package:musicon/library_controller.dart';
import 'package:musicon/library_store.dart';
import 'package:musicon/models.dart';
import 'package:musicon/ui.dart';
import 'online_test.dart' show MemoryLibrary;
import 'widget_test.dart' show FakeEngine;

const phoneSong = Track(
  id: 'device-external_primary-42',
  title: 'Música do aparelho',
  artist: 'Artista local',
  location: 'content://media/external_primary/audio/media/42',
  source: TrackSource.local,
  providerId: 'device',
);
const online = Track(
  id: 'online-one',
  title: 'Online',
  artist: 'Artista',
  location: 'https://example.com/a.mp3',
  source: TrackSource.online,
);

class FakeDeviceAudio implements DeviceAudioService {
  bool authorized = true, deletionAllowed = true;
  int deletions = 0;
  List<Track> rows = [phoneSong];
  final events = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<DeviceAudioSnapshot> scan({required bool requestPermission}) async =>
      DeviceAudioSnapshot(authorized, rows);
  @override
  Future<bool> delete(Track track) async {
    deletions++;
    if (deletionAllowed) rows = rows.where((t) => t.id != track.id).toList();
    return deletionAllowed;
  }

  @override
  Future<void> openSettings() async {}
  void dispose() => events.close();
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'musicon.audioPermissionAsked': true,
    }),
  );
  test(
    'automatic scan keeps content URIs, avoids duplicates and preserves collection references',
    () async {
      final source = FakeDeviceAudio();
      final store = MemoryLibrary();
      final library = LibraryController(store, device: source);
      await library.load();
      await library.refreshDevice();
      expect(library.tracks.single.location, phoneSong.location);
      await library.toggleFavorite(phoneSong);
      final playlist = (await library.createPlaylist('No celular'))!;
      await library.addToPlaylist(playlist, phoneSong);
      await library.refreshDevice();
      expect(library.tracks, hasLength(1));
      expect(library.isFavorite(phoneSong), isTrue);
      expect(playlist.trackIds, [phoneSong.id]);
      source.authorized = false;
      await library.refreshDevice();
      expect(library.tracks, isEmpty);
      expect(library.isFavorite(phoneSong), isTrue);
      source.authorized = true;
      await library.refreshDevice();
      expect(
        library.playlistTracks(playlist).single.location,
        phoneSong.location,
      );
      source.rows = [];
      await library.refreshDevice();
      expect(library.tracks, isEmpty);
      expect(playlist.trackIds, isEmpty);
      library.dispose();
      source.dispose();
    },
  );
  test(
    'deleting a device file respects cancellation and never deletes online tracks',
    () async {
      final source = FakeDeviceAudio();
      final library = LibraryController(MemoryLibrary(), device: source);
      await library.load();
      await library.refreshDevice();
      await library.toggleFavorite(phoneSong);
      final playlist = (await library.createPlaylist('Minha lista'))!;
      await library.addToPlaylist(playlist, phoneSong);
      source.deletionAllowed = false;
      expect(await library.deleteLocal(phoneSong), isFalse);
      expect(library.findTrack(phoneSong.id), isNotNull);
      await expectLater(library.deleteLocal(online), throwsStateError);
      expect(source.deletions, 1);
      source.deletionAllowed = true;
      expect(await library.deleteLocal(phoneSong), isTrue);
      expect(library.findTrack(phoneSong.id), isNull);
      expect(library.isFavorite(phoneSong), isFalse);
      expect(playlist.trackIds, isEmpty);
      library.dispose();
      source.dispose();
    },
  );
  test('legacy demo entries and references are removed on load', () async {
    const oldDemo = Track(
      id: 'demo-aurora',
      title: 'Aurora',
      artist: 'MusicON Lab',
      location: 'assets/audio/aurora.wav',
      source: TrackSource.demo,
    );
    final store = MemoryLibrary()
      ..data = LibraryData(
        tracks: [oldDemo, online],
        favorites: {oldDemo.id, online.id},
        playlists: [
          MusicPlaylist(
            id: 'p',
            name: 'Mista',
            trackIds: [oldDemo.id, online.id, 'demo-orbita'],
          ),
        ],
      );
    final library = LibraryController(store);
    await library.load();
    expect(library.tracks.single.id, online.id);
    expect(library.isFavorite(oldDemo), isFalse);
    expect(library.playlists.single.trackIds, [online.id]);
    library.dispose();
  });
  testWidgets(
    'device-file deletion requires confirmation and clears a deleted item from player',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = FakeDeviceAudio();
      final library = LibraryController(MemoryLibrary(), device: source);
      await library.load();
      await library.refreshDevice();
      final engine = FakeEngine();
      await tester.pumpWidget(MusicOnApp(library: library, engine: engine));
      await tester.pumpAndSettle();
      expect(find.text('Explorar músicas'), findsOneWidget);
      expect(find.text('Experimentar o som'), findsNothing);
      await tester.tap(find.text('Biblioteca'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(phoneSong.title));
      await tester.pumpAndSettle();
      expect(engine.playing, isTrue);
      await tester.tap(find.byTooltip('Opções da música'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir música do aparelho'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(source.deletions, 0);
      await tester.tap(find.byTooltip('Opções da música'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir música do aparelho'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir arquivo'));
      await tester.pumpAndSettle();
      expect(source.deletions, 1);
      expect(engine.current, isNull);
      expect(library.tracks, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      library.dispose();
      source.dispose();
      engine.dispose();
    },
  );
}
