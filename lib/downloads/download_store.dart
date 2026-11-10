import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'download_job.dart';

abstract class DownloadStore {
  Future<List<DownloadJob>> load();
  Future<void> save(List<DownloadJob> jobs);
}

class PreferencesDownloadStore implements DownloadStore {
  static const key = 'musicon.downloads.v1';
  @override
  Future<List<DownloadJob>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((j) => DownloadJob.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
  }

  @override
  Future<void> save(List<DownloadJob> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      key,
      jsonEncode(jobs.map((j) => j.toJson()).toList()),
    )) {
      throw StateError('Não foi possível salvar a fila.');
    }
  }
}
