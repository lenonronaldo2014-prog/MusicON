// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const githubRepository = 'lenonronaldo2014-prog/MusicON';
const releasesPage = 'https://github.com/$githubRepository/releases';

class AppVersion {
  const AppVersion(this.name, this.build);
  final String name;
  final int build;
  static AppVersion? parse(String input) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$',
    ).firstMatch(input);
    return match == null
        ? null
        : AppVersion(
            '${match[1]}.${match[2]}.${match[3]}',
            int.parse(match[4] ?? '0'),
          );
  }

  bool newerThan(AppVersion other) {
    final a = name.split('.').map(int.parse).toList();
    final b = other.name.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return build > other.build;
  }
}

class ReleaseInfo {
  const ReleaseInfo(this.version, this.download, this.notes);
  final AppVersion version;
  final Uri download;
  final String notes;
}

class UpdateService {
  UpdateService({
    http.Client? client,
    this.channel = const MethodChannel('musicon/app'),
  }) : _client = client ?? http.Client();
  final http.Client _client;
  final MethodChannel channel;
  Future<AppVersion> installed() async {
    final info = await channel.invokeMapMethod<String, Object?>('version');
    final name = info?['name'] as String?;
    final build = info?['build'] as int?;
    if (name == null || build == null || AppVersion.parse(name) == null) {
      throw StateError('Não foi possível identificar a versão instalada.');
    }
    return AppVersion(name, build);
  }

  Future<ReleaseInfo?> check() async {
    final response = await _client
        .get(
          Uri.https(
            'api.github.com',
            '/repos/$githubRepository/releases/latest',
          ),
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return null;
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw StateError(
        'O GitHub limitou as consultas. Tente novamente mais tarde.',
      );
    }
    if (response.statusCode != 200 || response.bodyBytes.length > 1024 * 1024) {
      throw StateError('Não foi possível consultar as atualizações.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['draft'] == true || data['prerelease'] == true) return null;
    final version = AppVersion.parse(data['tag_name'] as String? ?? '');
    if (version == null) {
      throw StateError('A versão publicada não foi reconhecida.');
    }
    for (final asset in data['assets'] as List? ?? []) {
      if (asset['name'] != 'MusicON.apk') continue;
      final uri = Uri.tryParse(asset['browser_download_url'] as String? ?? '');
      if (uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'github.com' &&
          uri.userInfo.isEmpty &&
          uri.path.startsWith('/$githubRepository/releases/download/')) {
        return ReleaseInfo(version, uri, data['body'] as String? ?? '');
      }
    }
    throw StateError('Esta versão ainda não tem um APK disponível.');
  }

  Future<void> openDownload(Uri url) async {
    await channel.invokeMethod<void>('openRelease', {'url': url.toString()});
  }

  void dispose() => _client.close();
}
