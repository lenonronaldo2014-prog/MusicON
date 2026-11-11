// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ffi';
import 'dart:io';
import 'dart:ui' show AppExitType;
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';
import '../update_service.dart';

class WindowsUpdateInstaller implements DesktopUpdateInstaller {
  WindowsUpdateInstaller._(this.directory);
  final String directory;

  static WindowsUpdateInstaller? current() {
    if (!Platform.isWindows) return null;
    // Keep the product ID in sync with desktop/windows/installer.iss.
    const key =
        r'Software\Microsoft\Windows\CurrentVersion\Uninstall\'
        '{68B4A41C-0DCA-4281-BE65-D3C4A4AE51D8}_is1';
    return using((arena) {
      final buffer = arena<Uint16>(32768);
      final size = arena<Uint32>()..value = 32768 * sizeOf<Uint16>();
      final result = RegGetValue(
        HKEY_CURRENT_USER,
        key.toNativeUtf16(allocator: arena),
        'InstallLocation'.toNativeUtf16(allocator: arena),
        RRF_RT_REG_SZ | RRF_SUBKEY_WOW6464KEY,
        nullptr,
        buffer.cast(),
        size,
      );
      if (result != ERROR_SUCCESS) return null;
      try {
        final executable = File(Platform.resolvedExecutable);
        final directory = Directory(
          buffer.cast<Utf16>().toDartString(),
        ).resolveSymbolicLinksSync();
        if (!p.windows.equals(
          executable.resolveSymbolicLinksSync(),
          p.join(directory, 'MusicON.exe'),
        )) {
          return null;
        }
        return WindowsUpdateInstaller._(directory);
      } on FileSystemException {
        return null;
      }
    });
  }

  @override
  Future<void> start(File installer) async {
    await Process.start(installer.path, [
      '/SP-',
      '/SILENT',
      '/NORESTART',
      '/NOCLOSEAPPLICATIONS',
      '/NORESTARTAPPLICATIONS',
      '/MUSICONUPDATE=$pid',
      '/DIR=$directory',
    ], mode: ProcessStartMode.detached);
    // Windows responds to this request through the existing exit listener,
    // which releases the player before the installer can replace any files.
    await ServicesBinding.instance.exitApplication(AppExitType.cancelable);
  }
}
