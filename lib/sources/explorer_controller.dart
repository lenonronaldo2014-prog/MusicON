import 'package:flutter/foundation.dart';
import '../models.dart';
import 'jamendo_source.dart';
import 'media_source.dart';

class ExplorerController extends ChangeNotifier {
  ExplorerController({required this.registry, required this.jamendo});
  final SourceRegistry registry;
  final JamendoSource jamendo;
  MediaCollection? results;
  String? error;
  Uri? activeLink;
  bool busy = false;
  String _query = '';
  int _generation = 0, _offset = 0;
  bool _disposed = false;
  List<Track> get tracks => results?.tracks ?? [];
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> submit(String input) =>
      RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(input.trim())
      ? resolve(input)
      : search(input);
  Future<void> resolve(String input) async {
    final generation = ++_generation;
    busy = true;
    error = null;
    results = null;
    activeLink = null;
    _changed();
    try {
      activeLink = parseWebLink(input);
      final found = await registry.resolve(input);
      if (_disposed || generation != _generation) return;
      results = found;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = e is SourceException
            ? e.message
            : 'Não foi possível analisar esse link.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        _changed();
      }
    }
  }

  Future<void> search(String query, {bool append = false}) async {
    if (append && (busy || results?.hasMore != true)) return;
    final generation = ++_generation;
    if (!append) {
      _query = query;
      _offset = 0;
      results = null;
    }
    busy = true;
    error = null;
    activeLink = null;
    _changed();
    try {
      final found = await jamendo.search(_query, offset: _offset);
      if (_disposed || generation != _generation) return;
      final all = <String, Track>{
        for (final t in [...?results?.tracks, ...found.tracks]) t.id: t,
      };
      results = MediaCollection(
        title: found.title,
        tracks: all.values.toList(),
        providerId: found.providerId,
        hasMore: found.hasMore,
      );
      _offset += 20;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = e is SourceException
            ? e.message
            : 'Não foi possível carregar o catálogo.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        _changed();
      }
    }
  }

  Future<void> more() => search(_query, append: true);
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
