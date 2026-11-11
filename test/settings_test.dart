import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
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
  for (final failure in [null, 'hash', 'redirect', 'truncated']) {
    test(
      'Windows updater validates the download before launch: ${failure ?? 'ok'}',
      () async {
        PackageInfo.setMockInitialValues(
          appName: 'MusicON',
          packageName: 'MusicON',
          version: '0.8.2',
          buildNumber: '14',
          buildSignature: '',
        );
        final temp = await Directory.systemTemp.createTemp(
          'musicon-update-test-',
        );
        addTearDown(() async {
          final updates = Directory(p.join(temp.path, 'updates'));
          if (await updates.exists()) {
            for (final name in ['MusicON-Setup.exe', 'MusicON-Setup.part']) {
              final file = File(p.join(updates.path, name));
              if (await file.exists()) await file.delete();
            }
            await updates.delete();
          }
          await temp.delete();
        });
        final bytes = utf8.encode('MusicON installer fixture');
        final installer = _RecordingInstaller();
        final requests = <String>[];
        final asset = Uri.parse(
          'https://github.com/$githubRepository/releases/download/v0.9.0/MusicON-Setup.exe',
        );
        final body = release(tag: 'v0.9.0')
          ..['assets'] = [
            {
              'name': 'MusicON-Setup.exe',
              'browser_download_url': asset.toString(),
              'size': bytes.length,
              'digest': 'sha256:${sha256.convert(bytes)}',
            },
          ];
        final updater = UpdateService(
          desktop: true,
          desktopInstaller: installer,
          updateDirectory: () async => temp,
          client: MockClient((request) async {
            final host = request.url.host;
            requests.add(host);
            if (host == 'api.github.com') {
              return http.Response(jsonEncode(body), 200);
            }
            expect(request.followRedirects, isFalse);
            if (request.url == asset) {
              return http.Response(
                '',
                302,
                headers: {
                  'location': failure == 'redirect'
                      ? 'https://example.com/fake.exe'
                      : 'https://release-assets.githubusercontent.com/fixture',
                },
              );
            }
            expect(host, 'release-assets.githubusercontent.com');
            final payload = switch (failure) {
              'hash' => [...bytes.take(bytes.length - 1), 0],
              'truncated' => bytes.take(bytes.length - 1).toList(),
              _ => bytes,
            };
            return http.Response.bytes(payload, 200);
          }),
        );
        addTearDown(updater.dispose);
        final releaseInfo = (await updater.check())!;
        expect(updater.canInstall(releaseInfo), isTrue);
        final progress = <double>[];
        var applying = false;
        final work = updater.install(
          releaseInfo,
          onProgress: progress.add,
          onInstalling: () => applying = true,
        );
        if (failure == null) {
          await work;
          expect(installer.bytes, bytes);
          expect(progress.last, 1);
          expect(applying, isTrue);
        } else {
          await expectLater(work, throwsStateError);
          expect(installer.bytes, isNull);
          expect(applying, isFalse);
          expect(requests, isNot(contains('example.com')));
        }
        expect(
          File(p.join(temp.path, 'updates', 'MusicON-Setup.part')).existsSync(),
          isFalse,
        );
      },
    );
  }
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

class _RecordingInstaller implements DesktopUpdateInstaller {
  List<int>? bytes;

  @override
  Future<void> start(File installer) async {
    bytes = await installer.readAsBytes();
  }
}
