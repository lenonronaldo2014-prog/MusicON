// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart';
import '../spotify/spotify_service.dart';

class WindowsSpotifyStore implements SpotifySessionStore {
  WindowsSpotifyStore({this.fileProvider});
  final Future<File> Function()? fileProvider;
  static const _cryptProtectUiForbidden = 0x1;
  Future<File> _file() async => fileProvider != null
      ? await fileProvider!()
      : File(
          p.join(
            (await getApplicationSupportDirectory()).path,
            'spotify-session.dpapi',
          ),
        );
  List<int> _crypt(List<int> bytes, {required bool decrypt}) {
    final input = calloc<CRYPT_INTEGER_BLOB>();
    final output = calloc<CRYPT_INTEGER_BLOB>();
    final data = calloc<Uint8>(bytes.length);
    data.asTypedList(bytes.length).setAll(0, bytes);
    input.ref.cbData = bytes.length;
    input.ref.pbData = data;
    try {
      final result = decrypt
          ? CryptUnprotectData(
              input,
              nullptr,
              nullptr,
              nullptr,
              nullptr,
              _cryptProtectUiForbidden,
              output,
            )
          : CryptProtectData(
              input,
              nullptr,
              nullptr,
              nullptr,
              nullptr,
              _cryptProtectUiForbidden,
              output,
            );
      if (result == 0) {
        throw StateError('Não foi possível proteger a sessão no Windows.');
      }
      return List<int>.of(output.ref.pbData.asTypedList(output.ref.cbData));
    } finally {
      if (output.ref.pbData != nullptr) LocalFree(output.ref.pbData);
      calloc.free(data);
      calloc.free(input);
      calloc.free(output);
    }
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      return utf8.decode(_crypt(await file.readAsBytes(), decrypt: true));
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(String value) async {
    if (value.length > 32768) throw StateError('Sessão inválida.');
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(
      _crypt(utf8.encode(value), decrypt: false),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
