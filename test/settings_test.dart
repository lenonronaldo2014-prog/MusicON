import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musicon/app_preferences.dart';
import 'package:musicon/update_service.dart';
import 'package:musicon/ui.dart';
import 'widget_test.dart' show MemoryStore, FakeEngine;
import 'package:musicon/library_controller.dart';

Map<String, Object?> release({String tag = 'v0.6.0', String? url}) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': false,
  'body': 'Uma versão nova',
  'assets': [
    {
      'name': 'MusicON.apk',
      'browser_download_url':
          url ??
          'https://github.com/$githubRepository/releases/download/$tag/MusicON.apk',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('musicon/app');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('theme and automatic checks survive restart', () async {
    final prefs = AppPreferences();
    await prefs.load();
    expect(prefs.color, MusicColor.violet);
    expect(prefs.autoUpdates, isFalse);
    await prefs.setColor(MusicColor.green);
    await prefs.setAutoUpdates(true);
    final restored = AppPreferences();
    await restored.load();
    expect(restored.color, MusicColor.green);
    expect(restored.autoUpdates, isTrue);
    prefs.dispose();
    restored.dispose();
  });
  test('versions compare numerically and same version does not prompt', () {
    expect(
      AppVersion.parse('v0.10.0')!.newerThan(const AppVersion('0.9.9', 99)),
      isTrue,
    );
    expect(
      AppVersion.parse('v0.5.0')!.newerThan(const AppVersion('0.5.0', 6)),
      isFalse,
    );
    expect(
      AppVersion.parse('v0.4.9')!.newerThan(const AppVersion('0.5.0', 6)),
      isFalse,
    );
    expect(AppVersion.parse('v0.5.0-beta'), isNull);
  });
  test(
    'release checks require official repository asset and handle failures',
    () async {
      var body = release();
      var status = 200;
      final service = UpdateService(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.github.com/repos/$githubRepository/releases/latest',
          );
          return http.Response(jsonEncode(body), status);
        }),
      );
      expect((await service.check())!.version.name, '0.6.0');
      body = release(url: 'https://example.com/MusicON.apk');
      await expectLater(service.check(), throwsStateError);
      body = release()..['prerelease'] = true;
      expect(await service.check(), isNull);
      status = 404;
      expect(await service.check(), isNull);
      status = 429;
      await expectLater(service.check(), throwsStateError);
      status = 500;
      await expectLater(service.check(), throwsStateError);
      service.dispose();
    },
  );
  test('updates choose the installer on Windows and APK on Android', () async {
    final body = release(tag: 'v0.8.0');
    (body['assets'] as List).add({
      'name': 'MusicON-Setup.exe',
      'browser_download_url':
          'https://github.com/$githubRepository/releases/download/v0.8.0/MusicON-Setup.exe',
    });
    for (final desktop in [false, true]) {
      final service = UpdateService(
        desktop: desktop,
        client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
      );
      expect(
        (await service.check())!.download.pathSegments.last,
        desktop ? 'MusicON-Setup.exe' : 'MusicON.apk',
      );
      service.dispose();
    }
  });
  testWidgets(
    'settings changes whole app theme and opens checked update download',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? opened;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'version') return {'name': '0.5.0', 'build': 6};
        opened = (call.arguments as Map)['url'] as String;
        return null;
      });
      final updates = UpdateService(
        client: MockClient(
          (_) async => http.Response(jsonEncode(release()), 200),
        ),
      );
      final prefs = AppPreferences();
      await prefs.load();
      final library = LibraryController(MemoryStore());
      await library.load();
      final engine = FakeEngine();
      await tester.pumpWidget(
        MusicOnApp(
          library: library,
          engine: engine,
          preferences: prefs,
          updates: updates,
        ),
      );
      await tester.tap(find.byTooltip('Configurações'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Azul'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(
          tester.element(find.text('Configurações')),
        ).colorScheme.primary,
        MusicColor.blue.color,
      );
      await tester.ensureVisible(find.text('Buscar atualizações'));
      await tester.tap(find.text('Buscar atualizações'));
      await tester.pumpAndSettle();
      expect(find.text('MusicON 0.6.0 disponível!'), findsOneWidget);
      await tester.ensureVisible(find.text('Baixar nova versão'));
      await tester.tap(find.text('Baixar nova versão'));
      await tester.pumpAndSettle();
      expect(
        opened,
        'https://github.com/$githubRepository/releases/download/v0.6.0/MusicON.apk',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      updates.dispose();
      prefs.dispose();
      library.dispose();
      engine.dispose();
    },
  );
}
