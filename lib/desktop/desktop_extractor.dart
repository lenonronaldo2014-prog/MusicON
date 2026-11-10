// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class DesktopExtractor {
  DesktopExtractor({String? javaPath, String? jarPath})
    : javaPath =
          javaPath ??
          p.join(
            p.dirname(Platform.resolvedExecutable),
            'support',
            'runtime',
            'bin',
            'javaw.exe',
          ),
      jarPath =
          jarPath ??
          p.join(
            p.dirname(Platform.resolvedExecutable),
            'support',
            'musicon-extractor.jar',
          );
  final String javaPath, jarPath;
  Process? _process;
  Future<void>? _starting;
  final _pending = <int, Completer<Object?>>{};
  int _id = 0;
  bool _closed = false;

  Future<void> _start() =>
      _starting ??= _doStart().whenComplete(() => _starting = null);
  Future<void> _doStart() async {
    if (_closed) throw StateError('Busca encerrada.');
    if (_process != null) return;
    if (!await File(javaPath).exists() || !await File(jarPath).exists()) {
      throw StateError(
        'Os arquivos da busca estão ausentes. Reinstale o MusicON.',
      );
    }
    final process = await Process.start(javaPath, [
      '-Xmx256m',
      '-Dfile.encoding=UTF-8',
      '-jar',
      jarPath,
    ], runInShell: false);
    if (_closed) {
      process.kill();
      throw StateError('Busca encerrada.');
    }
    _process = process;
    process.stderr.listen((_) {}, onError: (Object _) {});
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          try {
            final reply = jsonDecode(line) as Map<String, dynamic>;
            final pending = _pending.remove(reply['id']);
            if (pending == null) return;
            if (reply['error'] is String) {
              pending.completeError(StateError(reply['error'] as String));
            } else {
              pending.complete(reply['data']);
            }
          } catch (_) {
            _fail();
          }
        }, onError: (Object _) => _fail());
    unawaited(
      process.exitCode.then((_) {
        if (identical(_process, process)) {
          _process = null;
          _fail();
        }
      }),
    );
  }

  void _fail() {
    final requests = _pending.values.toList();
    _pending.clear();
    for (final request in requests) {
      if (!request.isCompleted) {
        request.completeError(
          StateError('A busca foi interrompida. Tente novamente.'),
        );
      }
    }
  }

  Future<Object?> invoke(String method, String value) async {
    if (!{'search', 'resolve', 'ping'}.contains(method) || value.length > 500) {
      throw ArgumentError('Busca inválida.');
    }
    await _start();
    final id = ++_id;
    final response = Completer<Object?>();
    unawaited(response.future.then<void>((_) {},onError:(Object _,StackTrace _){}));
    _pending[id] = response;
    try {
      _process!.stdin.add(
        utf8.encode(
          '${jsonEncode({'id': id, 'method': method, 'value': value})}\n',
        ),
      );
      await _process!.stdin.flush();
      return await response.future.timeout(const Duration(seconds: 75));
    } finally {
      _pending.remove(id);
    }
  }

  void dispose() {
    _closed = true;
    _process?.kill();
    _process = null;
    _fail();
  }
}
