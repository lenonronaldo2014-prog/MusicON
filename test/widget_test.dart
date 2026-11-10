import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicon/audio_engine.dart';
import 'package:musicon/library_controller.dart';
import 'package:musicon/library_store.dart';
import 'package:musicon/models.dart';
import 'package:musicon/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/testing.dart';
import 'package:musicon/downloads/download_controller.dart';
import 'package:musicon/online_services.dart';
import 'package:musicon/sources/explorer_controller.dart';
import 'package:musicon/sources/jamendo_source.dart';
import 'package:musicon/sources/media_source.dart';
import 'online_test.dart' as fixtures;

const fixtureTracks = [
  Track(
    id: 'fixture-a',
    title: 'Faixa A',
    artist: 'Artista teste',
    location: '/test/a.mp3',
    source: TrackSource.local,
  ),
  Track(
    id: 'fixture-b',
    title: 'Faixa B',
    artist: 'Artista teste',
    location: '/test/b.mp3',
    source: TrackSource.local,
  ),
  Track(
    id: 'fixture-c',
    title: 'Faixa C',
    artist: 'Artista teste',
    location: '/test/c.mp3',
    source: TrackSource.local,
  ),
];

class MemoryStore implements LibraryStore {
  LibraryData data = LibraryData(tracks: List.of(fixtureTracks));
  @override
  Future<LibraryData> load() async => LibraryData.fromJson(data.toJson());
  @override
  Future<void> save(LibraryData value) async {
    data = LibraryData.fromJson(value.toJson());
  }
}

class FakeEngine extends MusicEngine {
  List<Track> queue = [];
  int index = 0;
  @override
  Track? get current => queue.isEmpty ? null : queue[index];
  @override
  bool playing = false;
  @override
  bool get busy => false;
  @override
  bool get hasNext => index < queue.length - 1;
  @override
  bool get hasPrevious => index > 0;
  @override
  bool shuffle = false;
  @override
  bool repeat = false;
  @override
  Duration position = Duration.zero;
  @override
  Duration get duration => const Duration(seconds: 30);
  @override
  String? get error => null;
  @override
  Future<void> playQueue(List<Track> tracks, int selected) async {
    queue = tracks;
    index = selected;
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> removeTrack(String id) async {
    final currentId = current?.id;
    queue = queue.where((t) => t.id != id).toList();
    index = queue.indexWhere((t) => t.id == currentId);
    if (index < 0) index = 0;
    if (queue.isEmpty) playing = false;
    notifyListeners();
  }

  @override
  Future<void> toggle() async {
    playing = !playing;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration value) async {
    position = value;
    notifyListeners();
  }

  @override
  Future<void> next() async {
    if (hasNext) index++;
    notifyListeners();
  }

  @override
  Future<void> previous() async {
    if (hasPrevious) index--;
    notifyListeners();
  }

  @override
  Future<void> toggleRepeat() async {
    repeat = !repeat;
    notifyListeners();
  }

  @override
  Future<void> toggleShuffle() async {
    shuffle = !shuffle;
    notifyListeners();
  }
}

void main() {
  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk == null) return;
    final fonts = '$sdk/bin/cache/artifacts/material_fonts';
    final text = FontLoader('Roboto')
      ..addFont(
        File(
          '$fonts/roboto-regular.ttf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      )
      ..addFont(
        File(
          '$fonts/roboto-bold.ttf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    await text.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File(
          '$fonts/MaterialIcons-Regular.otf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    await icons.load();
  });
  test('preferences store serializes and restores user library', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferencesLibraryStore();
    final data = LibraryData(
      tracks: [
        const Track(
          id: 'local-test',
          title: 'Minha faixa',
          artist: 'Eu',
          location: '/app/music/test.mp3',
          source: TrackSource.local,
        ),
      ],
      favorites: {'local-test'},
      playlists: [
        MusicPlaylist(id: 'mix', name: 'Mix', trackIds: ['local-test']),
      ],
    );
    await store.save(data);
    final restored = await store.load();
    expect(restored.tracks.single.location, '/app/music/test.mp3');
    expect(restored.favorites, {'local-test'});
    expect(restored.playlists.single.trackIds, ['local-test']);
  });
  test('library round trip preserves mixed playlists and favorites', () async {
    final store = MemoryStore();
    final first = LibraryController(store);
    await first.load();
    final online = await first.addOnline(
      'Faixa online',
      'Artista',
      'https://example.com/audio.mp3',
    );
    final playlist = (await first.createPlaylist('Minha mistura'))!;
    await first.addToPlaylist(playlist, fixtureTracks.first);
    await first.addToPlaylist(playlist, online);
    await first.addToPlaylist(playlist, online);
    await first.toggleFavorite(online);
    final second = LibraryController(store);
    await second.load();
    expect(second.playlistTracks(second.playlists.single).map((t) => t.id), [
      fixtureTracks.first.id,
      online.id,
    ]);
    expect(second.isFavorite(online), isTrue);
    await second.removeFromPlaylist(
      second.playlists.single,
      fixtureTracks.first,
    );
    expect(second.playlists.single.trackIds, [online.id]);
  });
  test('online entries reject invalid schemes and deduplicate links', () async {
    final library = LibraryController(MemoryStore());
    await library.load();
    for (final url in [
      'http://example.com/a.mp3',
      'file:///sdcard/a.mp3',
      'abc',
      'https://user:secret@example.com/a.mp3',
    ]) {
      expect(validateAudioUrl(url), isNotNull);
    }
    final one = await library.addOnline('One', '', 'https://example.com/a.mp3');
    final two = await library.addOnline('Two', '', 'https://example.com/a.mp3');
    expect(one.id, two.id);
    expect(
      library.tracks.where((t) => t.source == TrackSource.online).length,
      1,
    );
    expect(await library.createPlaylist('   '), isNull);
  });
  test('rapid favorite updates persist in order', () async {
    final store = MemoryStore();
    final library = LibraryController(store);
    await library.load();
    await Future.wait([
      library.toggleFavorite(fixtureTracks.first),
      library.toggleFavorite(fixtureTracks.first),
      library.toggleFavorite(fixtureTracks[1]),
    ]);
    final restored = LibraryController(store);
    await restored.load();
    expect(restored.isFavorite(fixtureTracks.first), isFalse);
    expect(restored.isFavorite(fixtureTracks[1]), isTrue);
  });
  testWidgets('home, player, search and favorites work at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final library = LibraryController(MemoryStore());
    await library.load();
    final engine = FakeEngine();
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MusicOnApp(library: library, engine: engine),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dê play no seu mundo.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    const previewPath = String.fromEnvironment('PREVIEW_PATH');
    if (previewPath.isNotEmpty) {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(previewPath).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Faixa A'));
    await tester.pumpAndSettle();
    expect(engine.current?.id, fixtureTracks.first.id);
    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump();
    expect(engine.playing, isFalse);
    await tester.tap(find.text('Faixa A').last);
    await tester.pumpAndSettle();
    expect(find.text('AGORA NO SEU MUNDO'), findsOneWidget);
    await tester.tap(find.byTooltip('Ativar aleatório'));
    await tester.pump();
    expect(engine.shuffle, isTrue);
    await tester.tap(find.byTooltip('Repetir fila'));
    await tester.pump();
    expect(engine.repeat, isTrue);
    await tester.tap(find.byTooltip('Fechar player'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'faixa b');
    await tester.pumpAndSettle();
    expect(find.text('Faixa B'), findsOneWidget);
    expect(find.text('Faixa C'), findsNothing);
    await tester.tap(find.byTooltip('Favoritar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoritas'));
    await tester.pumpAndSettle();
    expect(find.text('Faixa B'), findsOneWidget);
    expect(find.text('Faixa C'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('create playlist and route online links to explorer', (
    tester,
  ) async {
    final library = LibraryController(MemoryStore());
    await library.load();
    await tester.pumpWidget(MusicOnApp(library: library, engine: FakeEngine()));
    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Criar playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Estrada');
    await tester.pump();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();
    expect(library.playlists.single.name, 'Estrada');
    await tester.tap(find.byTooltip('Adicionar música'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar link online'));
    await tester.pumpAndSettle();
    expect(find.text('Explore novos sons'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'https://open.spotify.com/playlist/123',
    );
    await tester.tap(find.text('Buscar ou analisar link'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir página no navegador'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'explorer searches, plays and saves a Jamendo playlist on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final library = LibraryController(MemoryStore());
      await library.load();
      final engine = FakeEngine();
      final jamendo = JamendoSource(
        clientId: 'test',
        client: MockClient(
          (_) async => fixtures.apiResponse([
            fixtures.apiTrack(1),
            fixtures.apiTrack(2),
          ]),
        ),
      );
      final services = OnlineServices(
        explorer: ExplorerController(
          registry: SourceRegistry([jamendo]),
          jamendo: jamendo,
        ),
        downloads: DownloadController(
          client: fixtures.FakeTransfer(),
          store: fixtures.MemoryDownloads(),
          library: library,
          directory: () async => Directory.systemTemp,
        ),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MusicOnApp(
            library: library,
            engine: engine,
            services: services,
          ),
        ),
      );
      await tester.tap(find.text('Explorar'));
      await tester.pumpAndSettle();
      const previewPath = String.fromEnvironment('EXPLORE_PREVIEW_PATH');
      if (previewPath.isNotEmpty) {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(previewPath).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.enterText(find.byType(TextField), 'jazz');
      await tester.tap(find.text('Buscar ou analisar link'));
      await tester.pumpAndSettle();
      expect(find.text('Faixa 1'), findsOneWidget);
      expect(find.byTooltip('Baixar áudio'), findsNothing);
      await tester.ensureVisible(find.text('Ouvir').first);
      await tester.tap(find.text('Ouvir').first);
      await tester.pumpAndSettle();
      expect(engine.current?.id, 'jamendo-1');
      final save = find.text('Salvar resultados como playlist');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(library.playlists.single.trackIds, ['jamendo-1', 'jamendo-2']);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byTooltip('Abrir downloads'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Abrir downloads'));
      await tester.pumpAndSettle();
      expect(find.text('Seus downloads aparecem aqui.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      services.dispose();
    },
  );
  testWidgets('small phone with larger text has no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final library = LibraryController(MemoryStore());
    await library.load();
    final engine = FakeEngine();
    await tester.pumpWidget(
      MaterialApp(
        theme: musicTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: MusicHome(library: library, engine: engine),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
