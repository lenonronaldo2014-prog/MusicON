import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../audio_engine.dart';
import '../library_controller.dart';
import '../models.dart';
import '../online_services.dart';
import '../sources/media_source.dart';
import '../sources/explorer_controller.dart';
import 'browser_page.dart';
import 'downloads_page.dart';

class ExplorerPage extends StatefulWidget {
  const ExplorerPage({
    super.key,
    required this.services,
    required this.library,
    required this.engine,
  });
  final OnlineServices services;
  final LibraryController library;
  final MusicEngine engine;
  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final input = TextEditingController();
  ExplorerController get explorer => widget.services.explorer;
  @override
  void initState() {
    super.initState();
    widget.services.downloads.load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _browser(Uri uri) async {
    if (widget.engine.playing) await widget.engine.toggle();
    if (!mounted) return;
    final link = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => BrowserPage(initialUri: uri)),
    );
    if (link != null && mounted) {
      input.text = link;
      await explorer.resolve(link);
    }
  }

  Future<void> _save(Track track) async {
    try {
      await widget.library.addResolved(track);
      if (mounted) _message('Faixa salva na biblioteca.');
    } catch (_) {
      if (mounted) {
        _message('Não foi possível salvar a faixa. Tente novamente.');
      }
    }
  }

  Future<void> _play(Track track) async {
    try {
      final saved = await widget.library.addResolved(track);
      await widget.engine.playQueue([saved], 0);
    } catch (_) {
      if (mounted) _message('Não foi possível preparar a reprodução.');
    }
  }

  Future<void> _download(Track track) async {
    try {
      await widget.services.downloads.enqueue(track);
      if (mounted) _message('Adicionada à fila de downloads.');
    } catch (e) {
      if (mounted) _message('$e');
    }
  }

  Future<void> _savePlaylist() async {
    try {
      final tracks = List<Track>.from(explorer.tracks);
      if (tracks.isEmpty) return;
      final playlist = await widget.library.createPlaylist(
        explorer.results!.title,
      );
      if (playlist == null) return;
      for (final track in tracks) {
        await widget.library.addResolved(track);
        await widget.library.addToPlaylist(playlist, track);
      }
      if (mounted) _message('Playlist salva na biblioteca.');
    } catch (_) {
      if (mounted) {
        _message(
          'Não foi possível salvar toda a playlist. Confira a biblioteca.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.services.explorer,
    builder: (context, _) {
      final state = widget.services.explorer;
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Explore novos sons',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Abrir downloads',
                icon: const Icon(Icons.download_for_offline_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DownloadsPage(
                      downloads: widget.services.downloads,
                      library: widget.library,
                      engine: widget.engine,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Uma busca. Várias formas de ouvir.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: input,
            onSubmitted: state.submit,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Nome no Jamendo ou link HTTPS',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Colar link',
                icon: const Icon(Icons.content_paste),
                onPressed: () async {
                  final content = await Clipboard.getData(Clipboard.kTextPlain);
                  if (mounted && content?.text != null) {
                    setState(() => input.text = content!.text!);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: state.busy ? null : () => state.submit(input.text),
            icon: const Icon(Icons.travel_explore),
            label: const Text('Buscar ou analisar link'),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.album_outlined, size: 18),
                label: const Text('Jamendo'),
                onPressed: state.busy
                    ? null
                    : () {
                        input.clear();
                        state.search('');
                      },
              ),
              ActionChip(
                avatar: const Icon(Icons.language, size: 18),
                label: const Text('Abrir site'),
                onPressed: () {
                  try {
                    _browser(parseWebLink(input.text));
                  } catch (e) {
                    _message('$e');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (state.busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (state.error != null)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2028),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.error!, style: const TextStyle(height: 1.5)),
                  if (state.activeLink != null)
                    TextButton.icon(
                      onPressed: () => _browser(state.activeLink!),
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Abrir página no navegador'),
                    ),
                ],
              ),
            ),
          if (state.results == null && !state.busy && state.error == null) ...[
            _sourceCard(
              Icons.link,
              'Cole um link de áudio',
              'MP3, M4A, AAC, WAV, OGG ou FLAC. Ouça agora ou baixe para o aparelho.',
            ),
            const SizedBox(height: 12),
            _sourceCard(
              Icons.library_music_outlined,
              'Descubra o catálogo Jamendo',
              'Busque artistas, faixas e estilos. Os créditos acompanham cada música.',
            ),
            const SizedBox(height: 12),
            _sourceCard(
              Icons.language,
              'Navegue por outras fontes',
              'Abra páginas dentro do MusicON. A disponibilidade de reprodução depende de cada site.',
            ),
          ],
          if (state.results != null) ...[
            Text(
              state.results!.title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            if (state.results!.providerId == 'jamendo')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  state.jamendo.demo
                      ? 'Conteúdo do Jamendo · modo de demonstração'
                      : 'Conteúdo do Jamendo',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            if (state.tracks.isEmpty && !state.busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Text(
                  'Nenhuma faixa encontrada. Tente outro artista ou estilo.',
                ),
              ),
            if (state.tracks.length > 1)
              TextButton.icon(
                onPressed: _savePlaylist,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Salvar resultados como playlist'),
              ),
            const SizedBox(height: 12),
            ...state.tracks.map(_trackCard),
            if (state.results!.hasMore)
              OutlinedButton(
                onPressed: state.busy ? null : state.more,
                child: const Text('Carregar mais'),
              ),
          ],
        ],
      );
    },
  );

  Widget _sourceCard(IconData icon, String title, String detail) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF19171F),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFB79AFF)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                detail,
                style: const TextStyle(
                  color: Colors.white60,
                  height: 1.5,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _trackCard(Track track) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF19171F),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: track.artworkUrl?.startsWith('https://') == true
                    ? Image.network(
                        track.artworkUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.album, size: 40),
                      )
                    : const Icon(Icons.album, size: 40),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _play(track),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Ouvir'),
            ),
            IconButton(
              tooltip: 'Salvar na biblioteca',
              onPressed: () => _save(track),
              icon: const Icon(Icons.library_add_outlined),
            ),
            if (track.downloadAllowed)
              IconButton(
                tooltip: 'Baixar áudio',
                onPressed: () => _download(track),
                icon: const Icon(Icons.download_outlined),
              ),
            if (track.originUrl != null)
              TextButton(
                onPressed: () => _browser(parseWebLink(track.originUrl!)),
                child: Text(
                  track.providerId == 'jamendo' ? 'Ver no Jamendo' : 'Fonte',
                ),
              ),
            if (track.licenseUrl?.startsWith('https://') == true)
              TextButton(
                onPressed: () => _browser(parseWebLink(track.licenseUrl!)),
                child: const Text('Licença'),
              ),
          ],
        ),
      ],
    ),
  );
}
