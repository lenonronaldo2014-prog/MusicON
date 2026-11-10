import '../models.dart';

enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  cancelled,
  interrupted,
}

class DownloadJob {
  DownloadJob({
    required this.track,
    this.status = DownloadStatus.queued,
    this.received = 0,
    this.total,
    this.message,
    this.localPath,
  });
  final Track track;
  DownloadStatus status;
  int received;
  int? total;
  String? message, localPath;
  double? get progress =>
      total == null || total! <= 0 ? null : (received / total!).clamp(0, 1);
  String get label => switch (status) {
    DownloadStatus.queued => 'Na fila',
    DownloadStatus.downloading => 'Baixando',
    DownloadStatus.completed => 'Disponível offline',
    DownloadStatus.failed => 'Falhou',
    DownloadStatus.cancelled => 'Cancelado',
    DownloadStatus.interrupted => 'Interrompido — tente novamente',
  };
  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'status': status.name,
    'received': received,
    'total': total,
    'message': message,
    'localPath': localPath,
  };
  factory DownloadJob.fromJson(Map<String, dynamic> value) => DownloadJob(
    track: Track.fromJson(Map<String, dynamic>.from(value['track'] as Map)),
    status: DownloadStatus.values.byName(value['status'] as String),
    received: value['received'] as int? ?? 0,
    total: value['total'] as int?,
    message: value['message'] as String?,
    localPath: value['localPath'] as String?,
  );
}
