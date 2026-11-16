import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicon/car_media_library.dart';
import 'package:musicon/daily_word.dart';
import 'package:musicon/library_controller.dart';
import 'package:musicon/music_audio_handler.dart';
import 'package:musicon/ui.dart';
import 'widget_test.dart' show FakeEngine, MemoryStore, fixtureTracks;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'car browsing preserves favorites, offline selection and playlist order',
    () async {
      final library = LibraryController(MemoryStore());
      await library.load();
      final online = await library.addOnline(
        'Faixa da estrada',
        'Artista',
        'https://example.com/a.mp3',
      );
      await library.toggleFavorite(online);
      final playlist = (await library.createPlaylist('Na estrada'))!;
      await library.addToPlaylist(playlist, online);
      await library.addToPlaylist(playlist, fixtureTracks.last);
      final car = CarMediaLibrary(library);
      expect(car.children(AudioService.browsableRootId).map((m) => m.title), [
        'Todas as músicas',
        'Favoritos',
        'No aparelho',
        'Playlists',
      ]);
      expect(car.children('offline').length, fixtureTracks.length);
      final favorite = car.resolve(car.children('favorites').single.id)!;
      expect(favorite.tracks.map((t) => t.id), [online.id]);
      final folder = car.children('playlists').single;
      final selection = car.resolve(car.children(folder.id).last.id)!;
      expect(selection.tracks.map((t) => t.id), [
        online.id,
        fixtureTracks.last.id,
      ]);
      expect(selection.index, 1);
      expect(car.resolve('track/missing/missing'), isNull);
      expect(car.children('unknown'), isEmpty);
    },
  );

  test(
    'car commands control the same queue and publish playback metadata',
    () async {
      final library = LibraryController(MemoryStore());
      await library.load();
      final engine = FakeEngine();
      final handler = MusicAudioHandler(engine, library);
      final tracks = await handler.getChildren('all');
      await handler.playFromMediaId(tracks[1].id);
      expect(engine.current?.id, fixtureTracks[1].id);
      expect(handler.queue.value.length, fixtureTracks.length);
      expect(handler.playbackState.value.queueIndex, 1);
      expect(handler.mediaItem.value?.duration, const Duration(seconds: 30));
      await handler.pause();
      await handler.pause();
      expect(engine.playing, false);
      await handler.play();
      expect(engine.playing, true);
      await handler.skipToNext();
      expect(engine.current?.id, fixtureTracks.last.id);
      await handler.skipToQueueItem(0);
      expect(engine.current?.id, fixtureTracks.first.id);
      await handler.seek(const Duration(seconds: 12));
      expect(engine.position, const Duration(seconds: 12));
      await handler.playFromSearch('Faixa B');
      expect(engine.queue.map((t) => t.id), [fixtureTracks[1].id]);
      await handler.playFromMediaId('missing');
      expect(engine.current?.id, fixtureTracks[1].id);
      await handler.setShuffleMode(AudioServiceShuffleMode.all);
      await handler.setShuffleMode(AudioServiceShuffleMode.all);
      expect(engine.shuffle, true);
      await handler.dispose();
      engine.dispose();
    },
  );

  test('favorite changes notify subscribed car browsers', () async {
    final library = LibraryController(MemoryStore());
    await library.load();
    final handler = MusicAudioHandler(FakeEngine(), library);
    final update = handler.subscribeToChildren('favorites').skip(1).first;
    await library.toggleFavorite(fixtureTracks.first);
    await update;
    expect(
      (await handler.getChildren('favorites')).single.title,
      fixtureTracks.first.title,
    );
    await handler.dispose();
  });

  const channel = MethodChannel('com.musicon.musicon/daily_word');
  late Map<String, Object> state;
  late List<String> calls;
  setUp(() {
    state = {
      'text': 'Um passo pequeno ainda é um passo.',
      'category': 'Motivacional',
      'reference': '',
      'enabled': true,
      'allowed': false,
    };
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'setEnabled') {
            state['enabled'] = (call.arguments as Map)['enabled'] as bool;
          }
          return state;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'denied permission stays visible, can disable, and refreshes on resume',
    () async {
      final controller = DailyWordController();
      await controller.initialize();
      expect(controller.text, state['text']);
      await controller.setEnabled(true);
      expect(calls, contains('requestPermission'));
      expect(controller.allowed, false);
      await controller.setEnabled(false);
      expect(controller.enabled, false);
      state['allowed'] = true;
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(controller.allowed, true);
      controller.dispose();
    },
  );

  test(
    'notification launch opens the daily word once and errors are recoverable',
    () async {
      state['openedFromNotification'] = true;
      final controller = DailyWordController();
      await controller.initialize();
      expect(controller.consumeOpenRequest(), true);
      expect(controller.consumeOpenRequest(), false);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'failed');
          });
      await controller.refresh();
      expect(controller.error, isNotNull);
      expect(controller.busy, false);
      expect(controller.text, isNotEmpty);
      controller.dispose();
    },
  );

  testWidgets(
    'daily word fits a small phone with larger text and opens from notification',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      state['openedFromNotification'] = true;
      final controller = DailyWordController();
      await controller.initialize();
      final library = LibraryController(MemoryStore());
      await library.load();
      await tester.pumpWidget(
        MusicOnApp(
          library: library,
          engine: FakeEngine(),
          dailyWord: controller,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(state['text']! as String), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: DailyWordCard(controller: controller),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
