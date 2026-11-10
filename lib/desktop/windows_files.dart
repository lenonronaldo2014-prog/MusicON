// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Returns false if Windows cannot move the confirmed file to the Recycle Bin.
bool recycleMusicFile(String path) {
  final operation = calloc<SHFILEOPSTRUCT>();
  final from = '$path\u0000'.toNativeUtf16();
  try {
    operation.ref.wFunc = FO_DELETE;
    operation.ref.pFrom = from;
    operation.ref.fFlags =
        FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_SILENT;
    return SHFileOperation(operation) == 0 &&
        operation.ref.fAnyOperationsAborted == 0 &&
        !File(path).existsSync();
  } finally {
    calloc.free(from);
    calloc.free(operation);
  }
}
