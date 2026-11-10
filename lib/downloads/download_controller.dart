import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../library_controller.dart';
import '../models.dart';
import '../sources/media_source.dart';
import 'audio_network.dart';
import 'download_job.dart';
import 'download_store.dart';

class DownloadController extends ChangeNotifier {
  DownloadController({
    required this.client,
    required this.store,
    required this.library,
    required this.directory,
    this.maxBytes = 256 * 1024 * 1024,
    this.openTrack,
  });
  final TransferClient client;
  final Future<AudioResponse> Function(Track track, Cancellation cancel)?
  openTrack;
  bool canDownload(Track track) =>
      track.source == TrackSource.online &&
      ((track.providerId == 'direct' && track.downloadAllowed) ||
          (track.providerId == 'youtube' && openTrack != null));
  DownloadJob? jobFor(String id) =>
      _jobs.where((j) => j.track.id == id).lastOrNull;
  final DownloadStore store;
  final LibraryController library;
  final Future<Directory> Function() directory;
  final int maxBytes;
  final List<DownloadJob> _jobs = [];
  List<DownloadJob> get jobs => List.unmodifiable(_jobs.reversed);
  String? error;
  bool _working = false,
      _disposed = false,
      _loaded = false,
      _loadFailed = false;
  Cancellation? _active;
  Future<void>? _loading;
  Future<void> _saveTail = Future.value();
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  String _basename(DownloadJob job) =>
      'musicon-${sha256.convert(utf8.encode(job.track.id))}';

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      _jobs.addAll(await store.load());
      final root = await directory();
      for (final job in _jobs) {
        // A process may stop after the library commit but before the history save.
        final saved = library.findTrack(job.track.id);
        if (saved?.source == TrackSource.local &&
            await File(saved!.location).exists()) {
          job.status = DownloadStatus.completed;
          job.localPath = saved.location;
          job.received = await File(saved.location).length();
          job.total = job.received;
        }
        if ({
          DownloadStatus.queued,
          DownloadStatus.downloading,
        }.contains(job.status)) {
          job.status = DownloadStatus.interrupted;
          job.received = 0;
          job.total = null;
          final partial = File(p.join(root.path, '${_basename(job)}.part'));
          if (await partial.exists()) await partial.delete();
        }
        if (job.status == DownloadStatus.completed &&
            (job.localPath == null || !await File(job.localPath!).exists())) {
          job.status = DownloadStatus.failed;
          job.message = 'O arquivo não está mais no aparelho.';
          final missing = library.findTrack(job.track.id);
          if (missing?.source == TrackSource.local) {
            await library.addResolved(job.track.asOnline(), replaceLocal: true);
          }
        }
      }
      await _save();
    } catch (_) {
      _loadFailed = true;
      error =
          'Não foi possível recuperar os downloads. Reabra o aplicativo para tentar novamente.';
    }
    _changed();
  }

  Future<void> _save() {
    if (_loadFailed) {
      return Future.error(StateError('A fila não pôde ser recuperada.'));
    }
    final snapshot = _jobs
        .map((j) => DownloadJob.fromJson(j.toJson()))
        .toList();
    final next = _saveTail.then((_) => store.save(snapshot));
    _saveTail = next.catchError((Object _) {});
    return next;
  }

  Future<DownloadJob> enqueue(Track track) async {
    await load();
    if (!canDownload(track)) {
      throw const SourceException(
        'Esta faixa está disponível apenas para reprodução online.',
      );
    }
    parseWebLink(track.location);
    if (_loadFailed) {
      throw const SourceException(
        'Reabra o app para recuperar a fila de downloads.',
      );
    }
    final local = library.findTrack(track.id);
    if (local?.source == TrackSource.local &&
        await File(local!.location).exists()) {
      throw const SourceException(
        'Esta faixa já está salva no aparelho. Abra a biblioteca para ouvir.',
      );
    }
    for (final job in _jobs) {
      if (job.track.id != track.id) continue;
      if ({
        DownloadStatus.failed,
        DownloadStatus.cancelled,
        DownloadStatus.interrupted,
      }.contains(job.status)) {
        await retry(job);
      }
      return job;
    }
    if (_jobs.length >= 100) {
      throw const SourceException(
        'Limpe os downloads finalizados antes de adicionar mais.',
      );
    }
    final job = DownloadJob(track: track);
    _jobs.add(job);
    try {
      await _save();
    } catch (_) {
      _jobs.remove(job);
      throw const SourceException('Não foi possível salvar o download.');
    }
    _changed();
    unawaited(_pump());
    return job;
  }

  Future<int> enqueueAll(List<Track> tracks) async {
    var count = 0;
    for (final track in tracks) {
      final current = library.findTrack(track.id) ?? track;
      if (!canDownload(current)) continue;
      await enqueue(current);
      count++;
    }
    return count;
  }

  Future<void> removeOffline(Track track) async {
    final current = library.findTrack(track.id) ?? track;
    if (current.source != TrackSource.local) return;
    final root = p.normalize(p.absolute((await directory()).path));
    final target = p.normalize(p.absolute(current.location));
    if (!p.isWithin(root, target) ||
        !p.basename(target).startsWith('musicon-') ||
        current.originUrl == null) {
      throw const SourceException(
        'Somente downloads do MusicON podem ser removidos aqui.',
      );
    }
    if (jobFor(current.id)?.status == DownloadStatus.downloading) {
      throw const SourceException('Aguarde o download terminar.');
    }
    await library.addResolved(current.asOnline(), replaceLocal: true);
    try {
      final file = File(target);
      if (await file.exists()) await file.delete();
    } catch (_) {
      await library.addResolved(current);
      throw const SourceException('Não foi possível remover o arquivo.');
    }
    _jobs.removeWhere((j) => j.track.id == current.id);
    await _save();
    _changed();
  }

  Future<void> retry(DownloadJob job) async {
    if (!{
      DownloadStatus.failed,
      DownloadStatus.cancelled,
      DownloadStatus.interrupted,
    }.contains(job.status)) {
      return;
    }
    final previous = job.status;
    job.status = DownloadStatus.queued;
    job.message = null;
    job.received = 0;
    job.total = null;
    try {
      await _save();
    } catch (_) {
      job.status = previous;
      throw const SourceException('Não foi possível salvar a tentativa.');
    }
    _changed();
    unawaited(_pump());
  }

  Future<void> cancel(DownloadJob job) async {
    if (job.status == DownloadStatus.downloading) {
      _active?.cancel();
      return;
    }
    if (job.status != DownloadStatus.queued) return;
    job.status = DownloadStatus.cancelled;
    _changed();
    try {
      await _save();
    } catch (_) {
      error = 'Não foi possível salvar o cancelamento.';
      _changed();
    }
  }

  Future<void> clearFinished() async {
    _jobs.removeWhere(
      (j) =>
          j.status != DownloadStatus.downloading &&
          j.status != DownloadStatus.queued,
    );
    try {
      await _save();
    } catch (_) {
      error = 'Não foi possível atualizar o histórico.';
    }
    _changed();
  }

  Future<void> _pump() async {
    if (_working || _disposed) return;
    _working = true;
    try {
      while (!_disposed) {
        final queued = _jobs.where((j) => j.status == DownloadStatus.queued);
        if (queued.isEmpty) break;
        final job = queued.first;
        _active = Cancellation();
        job.status = DownloadStatus.downloading;
        _changed();
        try {
          await _save();
          await _transfer(job, _active!);
        } on TransferCancelled {
          job.status = DownloadStatus.cancelled;
        } catch (e) {
          job.status = DownloadStatus.failed;
          job.message = e is SourceException
              ? e.message
              : 'Download interrompido. Verifique a conexão e o espaço no aparelho.';
        } finally {
          _active = null;
          try {
            await _save();
          } catch (_) {
            error = 'Não foi possível salvar o histórico de downloads.';
          }
          _changed();
        }
      }
    } finally {
      _working = false;
    }
  }

  Future<void> _transfer(DownloadJob job, Cancellation cancel) async {
    AudioResponse? response;
    IOSink? sink;
    File? partial, completed;
    var committed = false;
    try {
      cancel.check();
      response = job.track.providerId == 'youtube'
          ? await openTrack!(job.track, cancel)
          : await client.open(parseWebLink(job.track.location), cancel);
      cancel.check();
      if (response.length != null && response.length! > maxBytes) {
        throw const SourceException(
          'O arquivo ultrapassa o limite de 256 MB por faixa.',
        );
      }
      job.total = response.length;
      final root = await directory();
      await root.create(recursive: true);
      partial = File(p.join(root.path, '${_basename(job)}.part'));
      sink = partial.openWrite();
      // Sink errors can complete `done` before close() is awaited.
      unawaited(sink.done.catchError((Object _) {}));
      final prefix = <int>[];
      String? extension;
      final clock = Stopwatch()..start();
      await for (final chunk in response.stream) {
        cancel.check();
        job.received += chunk.length;
        if (job.received > maxBytes) {
          throw const SourceException(
            'O arquivo ultrapassa o limite de 256 MB por faixa.',
          );
        }
        if (extension == null) {
          prefix.addAll(chunk.take(64 - prefix.length));
          if (prefix.length >= 16) {
            extension = detectAudio(prefix, response.contentType);
          }
        }
        sink.add(chunk);
        if (clock.elapsedMilliseconds >= 150) {
          _changed();
          clock.reset();
        }
      }
      cancel.check();
      if (job.received == 0) {
        throw const SourceException('O servidor retornou um arquivo vazio.');
      }
      extension ??= detectAudio(prefix, response.contentType);
      if (response.length != null && job.received != response.length) {
        throw const SourceException(
          'O download ficou incompleto. Tente novamente.',
        );
      }
      await sink.flush();
      await sink.close();
      sink = null;
      cancel.check();
      completed = await partial.rename(
        p.join(root.path, '${_basename(job)}.$extension'),
      );
      // No cancellation after this point: saving the complete file is a single commit.
      await library.addResolved(job.track.asLocal(completed.path));
      committed = true;
      job.localPath = completed.path;
      job.status = DownloadStatus.completed;
    } catch (_) {
      cancel.check();
      rethrow;
    } finally {
      response?.close();
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (partial != null && await partial.exists()) await partial.delete();
      if (!committed && completed != null && await completed.exists()) {
        await completed.delete();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _active?.cancel();
    super.dispose();
  }
}
