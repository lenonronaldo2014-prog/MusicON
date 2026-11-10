import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicon/library_controller.dart';
import 'package:musicon/models.dart';
import 'package:musicon/newpipe_prototype.dart';
import 'package:musicon/ui.dart';
import 'widget_test.dart' show FakeEngine, MemoryStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('musicon/newpipe');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'online favorites and playlists survive reload without signed URLs',
    () async {
      final store = MemoryStore();
      final library = LibraryController(store);
      await library.load();
      const track = Track(
        id: 'youtube-demo',
        title: 'Minha música',
        artist: 'Artista',
        location: 'https://media.example.com/audio?secret=temporary',
        originUrl: 'https://www.youtube.com/watch?v=demo',
        source: TrackSource.online,
        providerId: 'youtube',
        artworkUrl: 'https://example.com/cover.jpg',
      );
      await library.toggleFavorite(track);
      final playlist = (await library.createPlaylist('Meu momento'))!;
      await library.addToPlaylist(playlist, track);
      await library.addToPlaylist(playlist, track);
      final restored = LibraryController(store);
      await restored.load();
      final saved = restored.findTrack(track.id)!;
      expect(saved.location, track.originUrl);
      expect(saved.artworkUrl, track.artworkUrl);
      expect(restored.isFavorite(saved), isTrue);
      expect(
        restored.playlistTracks(restored.playlists.single).single.id,
        track.id,
      );
      expect(store.data.toJson().toString(), isNot(contains('secret=')));
      await restored.removeFromPlaylist(restored.playlists.single, saved);
      expect(restored.playlistTracks(restored.playlists.single), isEmpty);
      library.dispose();
      restored.dispose();
    },
  );

  testWidgets(
    'original home, online favorite, playlist creation and ordered/shuffle queue',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => [
          {
            'title': 'Som um',
            'artist': 'Artista',
            'url': 'https://youtu.be/one',
          },
          {
            'title': 'Som dois',
            'artist': 'Artista',
            'url': 'https://youtu.be/two',
          },
        ],
      );
      final library = LibraryController(MemoryStore());
      await library.load();
      final engine = FakeEngine();
      final discovery = PrototypeController(NewPipeSource(), engine);
      await tester.pumpWidget(
        MusicOnApp(library: library, engine: engine, discovery: discovery),
      );
      expect(find.text('Dê play no seu mundo.'), findsOneWidget);
      expect(find.text('Sua música.\nSeu universo.'), findsOneWidget);
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('online-query')), 'som');
      await tester.tap(find.byTooltip('Buscar online'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favoritar').first);
      await tester.pumpAndSettle();
      expect(library.isFavorite(library.tracks.last), isTrue);
      await tester.tap(find.byTooltip('Opções da música').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar à playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar nova playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Meu momento');
      await tester.pump();
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();
      expect(library.playlists.single.trackIds, hasLength(1));
      // A second stable track verifies real queue order and navigation.
      final second = Track(
        id: 'youtube-https://youtu.be/two',
        title: 'Som dois',
        artist: 'Artista',
        location: 'https://youtu.be/two',
        originUrl: 'https://youtu.be/two',
        source: TrackSource.online,
        providerId: 'youtube',
      );
      await library.addToPlaylist(library.playlists.single, second);
      await tester.tap(find.text('Biblioteca'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Playlists'));
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meu momento'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tocar aleatório'));
      await tester.pumpAndSettle();
      expect(engine.shuffle, isTrue);
      expect(engine.queue, hasLength(2));
      await tester.tap(find.text('Meu momento'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tocar em sequência'));
      await tester.pumpAndSettle();
      expect(engine.shuffle, isFalse);
      expect(engine.current!.title, 'Som um');
      await engine.next();
      expect(engine.current!.title, 'Som dois');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      library.dispose();
      discovery.dispose();
      engine.dispose();
    },
  );
}
