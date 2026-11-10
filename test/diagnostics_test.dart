import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musicon/diagnostics_service.dart';
import 'package:musicon/settings_page.dart';
import 'package:musicon/app_preferences.dart';
import 'package:musicon/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(DiagnosticsService.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test(
    'diagnostics retain code locations without messages, URLs or local paths',
    () async {
      Map? recorded;
      messenger.setMockMethodCallHandler(DiagnosticsService.channel, (
        call,
      ) async {
        recorded = call.arguments as Map;
        return null;
      });
      final stack = StackTrace.fromString(
        '#0 Player.load (package:musicon/player.dart:20:3)\n#1 File.read (file:///storage/emulated/0/private-name.mp3:2:1)\n#2 secret (https://example.com/?token=private-token)',
      );
      await const DiagnosticsService().record(
        'dart',
        StateError('private-token and private-name.mp3'),
        stack,
      );
      expect(recorded!['frames'], [
        'Player.load(package:musicon/player.dart:20:3)',
      ]);
      expect(recorded!['type'], 'StateError');
      expect(jsonEncode(recorded), isNot(contains('private-token')));
      expect(jsonEncode(recorded), isNot(contains('private-name')));
    },
  );

  test('failure recording cannot raise another application error', () async {
    messenger.setMockMethodCallHandler(
      DiagnosticsService.channel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    await const DiagnosticsService().record(
      'dart',
      StateError('test'),
      StackTrace.empty,
    );
  });

  testWidgets('local diagnostics open and copy only on user action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = AppPreferences();
    await prefs.load();
    final updates = UpdateService();
    addTearDown(prefs.dispose);
    addTearDown(updates.dispose);
    var reads = 0;
    String? clipboard;
    const report = '{"version":"0.7.3","androidApi":28,"errors":[]}';
    messenger.setMockMethodCallHandler(DiagnosticsService.channel, (
      call,
    ) async {
      if (call.method == 'version') return {'name': '0.7.3', 'build': 11};
      expect(call.method, 'diagnosticsRead');
      reads++;
      return report;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(preferences: prefs, updates: updates),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 0);
    await tester.scrollUntilVisible(find.text('Diagnóstico de problemas'), 250);
    await tester.tap(find.text('Diagnóstico de problemas'));
    await tester.pumpAndSettle();
    expect(find.text('Diagnóstico local'), findsOneWidget);
    expect(reads, 1);
    expect(clipboard, isNull);
    await tester.tap(find.text('Copiar'));
    await tester.pumpAndSettle();
    expect(clipboard, report);
    expect(find.text('Diagnóstico copiado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
