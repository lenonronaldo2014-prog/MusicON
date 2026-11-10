import 'dart:convert';
import 'dart:io';
import 'package:musicon/desktop/desktop_extractor.dart';

Future<void> main(List<String> args) async {
  final extractor = DesktopExtractor(javaPath: args[0], jarPath: args[1]);
  try {
    final ping = await extractor.invoke('ping', '') as Map;
    final results =
        await extractor.invoke('search', 'Blender Big Buck Bunny') as List;
    final audio =
        await extractor.invoke(
              'resolve',
              'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
            )
            as Map;
    stdout.writeln(
      jsonEncode({
        'extractor': ping['version'],
        'results': results.length,
        'resolved': audio['stream'] is String,
      }),
    );
  } finally {
    extractor.dispose();
  }
}
