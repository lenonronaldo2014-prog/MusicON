import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'downloads/audio_network.dart';
import 'downloads/download_controller.dart';
import 'downloads/download_store.dart';
import 'library_controller.dart';
import 'newpipe_prototype.dart';
import 'sources/direct_source.dart';
import 'sources/explorer_controller.dart';
import 'sources/jamendo_source.dart';
import 'sources/media_source.dart';

class OnlineServices {
  OnlineServices({required this.explorer, required this.downloads, this.close});
  final ExplorerController explorer;
  final DownloadController downloads;
  final void Function()? close;
  factory OnlineServices.create(
    LibraryController library, {
    NewPipeSource? source,
  }) {
    final httpClient = http.Client();
    final transfer = HttpTransferClient();
    const configured = String.fromEnvironment('JAMENDO_CLIENT_ID');
    // Public read-only test client documented by Jamendo. Never used in release.
    const demo = kDebugMode && configured == '';
    final jamendo = JamendoSource(
      clientId: demo ? '709fa152' : configured,
      client: httpClient,
      demo: demo,
    );
    return OnlineServices(
      explorer: ExplorerController(
        jamendo: jamendo,
        registry: SourceRegistry([
          jamendo,
          DirectAudioSource(NetworkAudioInspector(transfer)),
        ]),
      ),
      downloads: DownloadController(
        client: transfer,
        openTrack: source?.openDownload,
        store: PreferencesDownloadStore(),
        library: library,
        directory: () async => Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'downloads'),
        ),
      ),
      close: httpClient.close,
    );
  }
  void dispose() {
    explorer.dispose();
    downloads.dispose();
    close?.call();
  }
}
