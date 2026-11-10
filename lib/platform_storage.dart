import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<Directory> musicStorageDirectory() => Platform.isWindows
    ? getApplicationSupportDirectory()
    : getApplicationDocumentsDirectory();
