import 'package:flutter/material.dart';
import '../audio_engine.dart';
import '../downloads/download_controller.dart';
import '../downloads/download_job.dart';
import '../library_controller.dart';

String byteLabel(int value) => value >= 1024 * 1024
    ? '${(value / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(value / 1024).toStringAsFixed(0)} KB';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({
    super.key,
    required this.downloads,
    required this.library,
    required this.engine,
  });
  final DownloadController downloads;
  final LibraryController library;
  final MusicEngine engine;
  Future<void> _action(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Downloads'),
      actions: [
        IconButton(
          tooltip: 'Limpar histórico finalizado',
          onPressed: () => _action(context, downloads.clearFinished),
          icon: const Icon(Icons.playlist_remove),
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: downloads,
      builder: (context, _) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Mantenha o MusicON aberto durante o download. Arquivos completos ficam disponíveis offline na biblioteca.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          if (downloads.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(downloads.error!),
            ),
          Expanded(
            child: downloads.jobs.isEmpty
                ? const Center(child: Text('Seus downloads aparecem aqui.'))
                : ListView.builder(
                    itemCount: downloads.jobs.length,
                    itemBuilder: (context, index) {
                      final job = downloads.jobs[index];
                      final active =
                          job.status == DownloadStatus.downloading ||
                          job.status == DownloadStatus.queued;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.track.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    job.message ?? job.label,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (job.status ==
                                      DownloadStatus.downloading) ...[
                                    const SizedBox(height: 10),
                                    LinearProgressIndicator(
                                      value: job.progress,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${byteLabel(job.received)}${job.total == null ? '' : ' / ${byteLabel(job.total!)}'}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (active)
                              IconButton(
                                tooltip: 'Cancelar download',
                                onPressed: () => _action(
                                  context,
                                  () => downloads.cancel(job),
                                ),
                                icon: const Icon(Icons.close),
                              ),
                            if (!active &&
                                job.status != DownloadStatus.completed)
                              IconButton(
                                tooltip: 'Tentar novamente',
                                onPressed: () => _action(
                                  context,
                                  () => downloads.retry(job),
                                ),
                                icon: const Icon(Icons.refresh),
                              ),
                            if (job.status == DownloadStatus.completed)
                              IconButton(
                                tooltip: 'Remover download',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _action(
                                  context,
                                  () => downloads.removeOffline(
                                    library.findTrack(job.track.id) ??
                                        job.track,
                                  ),
                                ),
                              ),
                            if (job.status == DownloadStatus.completed)
                              IconButton(
                                tooltip: 'Tocar download',
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () {
                                  final track = library.findTrack(job.track.id);
                                  if (track != null) {
                                    engine.playQueue([track], 0);
                                  }
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
