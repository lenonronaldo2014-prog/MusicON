// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  const ReleaseInfo(
    this.version,
    this.download,
    this.notes, {
    this.size,
    this.sha256,
  });
  final AppVersion version;
  final Uri download;
  final String notes;
  final int? size;
  final String? sha256;
}

abstract interface class DesktopUpdateInstaller {
  Future<void> start(File installer);
}

class UpdateService {
  UpdateService({
    http.Client? client,
    this.channel = const MethodChannel('musicon/app'),
    this.desktop = false,
    this.desktopInstaller,
    Future<Directory> Function()? updateDirectory,
  }) : _client = client ?? http.Client(),
       _updateDirectory = updateDirectory ?? getTemporaryDirectory;
  final http.Client _client;
  final MethodChannel channel;
  final bool desktop;
  final DesktopUpdateInstaller? desktopInstaller;
  final Future<Directory> Function() _updateDirectory;
  bool _installing = false;
  static const _maxInstallerBytes = 250 * 1024 * 1024;
  Future<AppVersion> installed() async {
    if (desktop) {
      final info = await PackageInfo.fromPlatform();
      return AppVersion(info.version, int.tryParse(info.buildNumber) ?? 0);
    }
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
    final tag = data['tag_name'] as String? ?? '';
    final version = AppVersion.parse(tag);
    if (version == null) {
      throw StateError('A versão publicada não foi reconhecida.');
    }
    final assetName = desktop ? 'MusicON-Setup.exe' : 'MusicON.apk';
    for (final asset in data['assets'] as List? ?? []) {
      if (asset['name'] != assetName) {
        continue;
      }
      final uri = Uri.tryParse(asset['browser_download_url'] as String? ?? '');
      if (uri != null &&
          _officialAsset(uri) &&
          uri.path == '/$githubRepository/releases/download/$tag/$assetName') {
        final digest = asset['digest'];
        final hash = digest is String && digest.startsWith('sha256:')
            ? digest.substring('sha256:'.length)
            : null;
        return ReleaseInfo(
          version,
          uri,
          data['body'] as String? ?? '',
          size: asset['size'] is int ? asset['size'] as int : null,
          sha256: hash,
        );
      }
    }
    throw StateError(
      desktop
          ? 'Esta versão ainda não tem um instalador Windows disponível.'
          : 'Esta versão ainda não tem um APK disponível.',
    );
  }

  static bool _secure(Uri url) =>
      url.scheme == 'https' &&
      url.port == 443 &&
      url.userInfo.isEmpty &&
      !url.hasFragment;

  static bool _officialAsset(Uri url) =>
      _secure(url) &&
      url.host == 'github.com' &&
      !url.hasQuery &&
      url.path.startsWith('/$githubRepository/releases/download/');

  bool canInstall(ReleaseInfo release) =>
      desktop &&
      desktopInstaller != null &&
      _officialAsset(release.download) &&
      release.download.pathSegments.last == 'MusicON-Setup.exe' &&
      release.size != null &&
      release.size! > 0 &&
      release.size! <= _maxInstallerBytes &&
      RegExp(r'^[a-f0-9]{64}$').hasMatch(release.sha256 ?? '');

  Future<void> install(
    ReleaseInfo release, {
    required void Function(double) onProgress,
    required void Function() onInstalling,
  }) async {
    if (_installing) throw StateError('Já há uma atualização em andamento.');
    if (!canInstall(release)) {
      throw StateError('Esta versão precisa ser instalada manualmente.');
    }
    _installing = true;
    File? partial;
    final abort = Completer<void>();
    final deadline = Timer(const Duration(minutes: 15), abort.complete);
    try {
      if (!release.version.newerThan(await installed())) {
        throw StateError('Seu MusicON já está atualizado.');
      }
      final folder = Directory(
        p.join((await _updateDirectory()).path, 'updates'),
      );
      await folder.create(recursive: true);
      partial = File(p.join(folder.path, 'MusicON-Setup.part'));
      final size = release.size!;
      final response = await _installerResponse(release.download, abort.future);
      if (response.statusCode != 200 ||
          (response.contentLength != null && response.contentLength != size)) {
        await response.stream.listen(null).cancel();
        throw StateError('O download da atualização não está disponível.');
      }
      final output = await partial.open(mode: FileMode.write);
      var received = 0;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 25),
        )) {
          received += chunk.length;
          if (received > size) {
            throw StateError('O tamanho da atualização não confere.');
          }
          await output.writeFrom(chunk);
          onProgress(received / size);
        }
      } finally {
        await output.close();
      }
      if (received != size ||
          (await sha256.bind(partial.openRead()).first).toString() !=
              release.sha256) {
        throw StateError(
          'O arquivo da atualização está incompleto ou inválido.',
        );
      }
      final path = p.join(folder.path, 'MusicON-Setup.exe');
      final setup = await partial.rename(path);
      onInstalling();
      await desktopInstaller!.start(setup);
    } catch (_) {
      _installing = false;
      rethrow;
    } finally {
      deadline.cancel();
      if (!abort.isCompleted) abort.complete();
      try {
        if (partial != null && await partial.exists()) await partial.delete();
      } on FileSystemException {
        // The next attempt truncates a leftover partial download.
      }
    }
  }

  Future<http.StreamedResponse> _installerResponse(
    Uri url,
    Future<void> abort,
  ) async {
    for (var redirects = 0; redirects <= 4; redirects++) {
      if (!_secure(url) ||
          (!_officialAsset(url) &&
              url.host != 'release-assets.githubusercontent.com' &&
              url.host != 'objects.githubusercontent.com')) {
        throw StateError('Endereço da atualização inválido.');
      }
      final response = await _client
          .send(
            http.AbortableRequest('GET', url, abortTrigger: abort)
              ..followRedirects = false
              ..headers['Accept-Encoding'] = 'identity',
          )
          .timeout(const Duration(seconds: 25));
      if (!{301, 302, 303, 307, 308}.contains(response.statusCode)) {
        return response;
      }
      await response.stream.listen(null).cancel();
      final location = response.headers['location'];
      if (location == null) break;
      url = url.resolve(location);
    }
    throw StateError('Não foi possível localizar o arquivo da atualização.');
  }

  Future<void> openDownload(Uri url) async {
    if (desktop) {
      if (!_officialAsset(url)) {
        throw StateError('Endereço de atualização inválido.');
      }
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError('Não foi possível abrir o navegador.');
      }
      return;
    }
    await channel.invokeMethod<void>('openRelease', {'url': url.toString()});
  }

  void dispose() => _client.close();
}
