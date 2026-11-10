// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'main_newpipe.dart' as android;
import 'main_windows.dart' as windows;

Future<void> main(List<String> args) =>
    Platform.isWindows ? windows.main(args) : android.main();
