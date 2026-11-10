import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicon/newpipe_prototype.dart';
import 'widget_test.dart' show FakeEngine;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('musicon/newpipe');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('each play resolves a fresh URL and never enables downloads', () async {
    var resolves = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'search') {
        return [
          {
            'title': 'Faixa',
            'artist': 'Artista',
            'url': 'https://www.youtube.com/watch?v=demo',
          },
        ];
      }
      resolves++;
      return {
        'title': 'Faixa',
        'artist': 'Artista',
        'url': 'https://www.youtube.com/watch?v=demo',
        'stream': 'https://media.example.com/audio?token=$resolves',
      };
    });
    final engine = FakeEngine();
    final state = PrototypeController(NewPipeSource(), engine);
    await state.search('Faixa');
    await state.play(state.results.single);
    expect(engine.current!.location, endsWith('token=1'));
    expect(engine.current!.downloadAllowed, isFalse);
    await state.play(state.results.single);
    expect(engine.current!.location, endsWith('token=2'));
    state.dispose();
  });

  test('source failures are visible and never reach the player', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(
        code: 'extraction_failed',
        message: 'Fonte indisponível',
      ),
    );
    final engine = FakeEngine();
    final state = PrototypeController(NewPipeSource(), engine);
    await state.search('https://www.youtube.com/watch?v=demo');
    expect(state.error, 'Fonte indisponível');
    expect(state.resolving, isFalse);
    expect(engine.current, isNull);
    state.dispose();
  });

  test('rejects malformed or insecure media addresses', () async {
    for (final stream in [
      'http://example.com/a',
      'https://u:p@example.com/a',
      'file:///a',
    ]) {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'stream': stream},
      );
      await expectLater(
        NewPipeSource().resolve('https://youtu.be/demo'),
        throwsStateError,
      );
    }
  });

  testWidgets('search and playback controls fit a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'search'
          ? [
              {
                'title': 'Faixa de teste',
                'artist': 'Artista',
                'url': 'https://youtu.be/demo',
              },
            ]
          : {
              'title': 'Faixa de teste',
              'artist': 'Artista',
              'url': 'https://youtu.be/demo',
              'stream': 'https://example.com/a.mp3',
            },
    );
    final engine = FakeEngine();
    final state = PrototypeController(NewPipeSource(), engine);
    await tester.pumpWidget(NewPipePrototype(controller: state));
    await tester.enterText(find.byKey(const Key('query')), 'teste');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Faixa de teste'));
    await tester.pumpAndSettle();
    expect(engine.playing, isTrue);
    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump();
    expect(engine.playing, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
