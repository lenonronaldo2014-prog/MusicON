import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DailyWordController extends ChangeNotifier with WidgetsBindingObserver {
  DailyWordController({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.musicon.musicon/daily_word');

  final MethodChannel _channel;
  String text = '';
  String category = '';
  String reference = '';
  bool enabled = false;
  bool allowed = false;
  bool busy = false;
  String? error;
  bool _openRequested = false;
  bool _disposed = false;
  Timer? _midnight;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openDailyWord') {
        _openRequested = true;
        await refresh();
      }
    });
    await refresh();
  }

  bool consumeOpenRequest() {
    final result = _openRequested;
    _openRequested = false;
    return result;
  }

  void _apply(Map<Object?, Object?>? state) {
    if (state == null || _disposed) return;
    text = state['text'] as String? ?? '';
    category = state['category'] as String? ?? '';
    reference = state['reference'] as String? ?? '';
    enabled = state['enabled'] == true;
    allowed = state['allowed'] == true;
    _openRequested |= state['openedFromNotification'] == true;
  }

  Future<void> refresh() async {
    if (busy || _disposed) return;
    await _perform(() async {
      _apply(await _channel.invokeMapMethod('getState'));
    });
    _midnight?.cancel();
    if (_disposed) return;
    final now = DateTime.now();
    _midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      refresh,
    );
  }

  Future<void> setEnabled(bool value) async {
    if (busy || _disposed) return;
    await _perform(() async {
      _apply(await _channel.invokeMapMethod('setEnabled', {'enabled': value}));
      if (value && !allowed) {
        _apply(await _channel.invokeMapMethod('requestPermission'));
      }
    });
  }

  Future<void> openSettings() =>
      _perform(() => _channel.invokeMethod<void>('openSettings'));

  Future<void> _perform(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (_) {
      error = 'Não foi possível atualizar o aviso. Tente novamente.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}

class DailyWordCard extends StatelessWidget {
  const DailyWordCard({super.key, required this.controller});
  final DailyWordController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Palavra do dia',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (controller.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                controller.category,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 6),
              Text(
                controller.text,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              if (controller.reference.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  controller.reference,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Receber por volta das 8h'),
              subtitle: const Text(
                'Uma mensagem de fé, motivação ou reflexão.',
              ),
              value: controller.enabled,
              onChanged: controller.busy ? null : controller.setEnabled,
            ),
            if (controller.enabled && !controller.allowed) ...[
              const Text(
                'Permita as notificações para receber sua palavra do dia.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => controller.setEnabled(true),
                    child: const Text('Permitir avisos'),
                  ),
                  TextButton(
                    onPressed: controller.busy ? null : controller.openSettings,
                    child: const Text('Configurações'),
                  ),
                ],
              ),
            ],
            if (controller.error != null) ...[
              Text(controller.error!),
              TextButton(
                onPressed: controller.busy ? null : controller.refresh,
                child: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
