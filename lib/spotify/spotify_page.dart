// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../library_controller.dart';
import '../models.dart';
import '../newpipe_prototype.dart';
import 'spotify_service.dart';

class SpotifyPage extends StatefulWidget {
  const SpotifyPage({
    super.key,
    required this.spotify,
    required this.library,
    required this.source,
  });
  final SpotifyService spotify;
  final LibraryController library;
  final NewPipeSource source;
  @override
  State<SpotifyPage> createState() => _SpotifyPageState();
}

class _SpotifyPageState extends State<SpotifyPage> {
  List<SpotifyPlaylist> playlists = [];
  bool busy = false;
  String? error;
  Future<void> _load({bool login = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (login) await widget.spotify.connect();
      final values = await widget.spotify.playlists();
      if (mounted) setState(() => playlists = values);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _fromLink() async {
    final input = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playlist por link'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://open.spotify.com/playlist/…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
    // Wait for the dialog route transition before disposing its text controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (!mounted || link == null || link.trim().isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final playlist = await widget.spotify.playlistFromLink(link);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SpotifyImportPage(
            playlist: playlist,
            spotify: widget.spotify,
            library: widget.library,
            source: widget.source,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.spotify.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Playlists do Spotify')),
    body: ListenableBuilder(
      listenable: widget.spotify,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sua coleção, no seu ritmo.',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Conectar é opcional. Leia suas playlists, escolha as versões encontradas no MusicON e salve uma coleção aqui. O Spotify fornece a lista, não os arquivos de áudio.',
                ),
                const SizedBox(height: 16),
                if (!widget.spotify.configured)
                  const Text(
                    'A conexão Spotify está em preparação nesta versão. O cadastro do MusicON precisa ser concluído antes de liberar o login.',
                  ),
                if (!widget.spotify.connected)
                  FilledButton.icon(
                    onPressed: busy || !widget.spotify.configured
                        ? null
                        : () => _load(login: true),
                    icon: const Icon(Icons.login),
                    label: Text(
                      busy ? 'Aguardando Spotify…' : 'Conectar ao Spotify',
                    ),
                  ),
                if (busy && !widget.spotify.connected)
                  TextButton(
                    onPressed: widget.spotify.cancelConnect,
                    child: const Text('Cancelar conexão'),
                  ),
                if (widget.spotify.connected)
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy ? null : _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Atualizar playlists'),
                      ),
                      TextButton.icon(
                        onPressed: busy ? null : _fromLink,
                        icon: const Icon(Icons.link),
                        label: const Text('Usar link de playlist'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                await widget.spotify.disconnect();
                                if (mounted) setState(() => playlists = []);
                              },
                        child: const Text('Desconectar'),
                      ),
                    ],
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!),
                  ),
              ],
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          Expanded(
            child: playlists.isEmpty
                ? Center(
                    child: Text(
                      widget.spotify.connected && !busy
                          ? 'Nenhuma playlist disponível para esta conta.'
                          : 'Seus favoritos e playlists do MusicON funcionam sem conectar.',
                    ),
                  )
                : ListView.builder(
                    itemCount: playlists.length,
                    itemBuilder: (context, i) => ListTile(
                      leading: const Icon(Icons.queue_music),
                      title: Text(playlists[i].name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => SpotifyImportPage(
                                  playlist: playlists[i],
                                  spotify: widget.spotify,
                                  library: widget.library,
                                  source: widget.source,
                                ),
                              ),
                            ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class SpotifyImportPage extends StatefulWidget {
  const SpotifyImportPage({
    super.key,
    required this.playlist,
    required this.spotify,
    required this.library,
    required this.source,
  });
  final SpotifyPlaylist playlist;
  final SpotifyService spotify;
  final LibraryController library;
  final NewPipeSource source;
  @override
  State<SpotifyImportPage> createState() => _SpotifyImportPageState();
}

class _SpotifyImportPageState extends State<SpotifyImportPage> {
  List<SpotifySong> songs = [];
  final Map<int, VideoResult> selected = {};
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    widget.spotify
        .songs(widget.playlist.id)
        .then((values) {
          if (mounted) {
            setState(() {
              songs = values;
              busy = false;
            });
          }
        })
        .catchError((Object e) {
          if (mounted) {
            setState(() {
              error = e.toString();
              busy = false;
            });
          }
        });
  }

  Future<void> _choose(int index) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final results = await widget.source.search(songs[index].query);
      if (!mounted) return;
      final choice = await showModalBottomSheet<VideoResult>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Escolha a versão para sua playlist',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? const Center(child: Text('Nenhuma versão encontrada.'))
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) => ListTile(
                          title: Text(
                            results[i].title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(results[i].artist),
                          onTap: () => Navigator.pop(context, results[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
      if (mounted && choice != null) setState(() => selected[index] = choice);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _import() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final tracks = selected.keys.toList()..sort();
      final values = tracks.map((i) {
        final v = selected[i]!;
        return Track(
          id: 'youtube-${v.url}',
          title: v.title,
          artist: v.artist,
          location: v.url,
          originUrl: v.url,
          artworkUrl: v.artwork,
          providerId: 'youtube',
          source: TrackSource.online,
          downloadAllowed: true,
        );
      }).toList();
      await widget.library.importCollection(widget.playlist.name, values);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Playlist salva na biblioteca do MusicON.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.playlist.name)),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Escolha a versão de cada música. Só as faixas confirmadas serão importadas; você pode pular as demais.',
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
        Expanded(
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(songs[i].title),
              subtitle: Text(
                selected[i]?.title ?? songs[i].artist,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              leading: Icon(
                selected.containsKey(i)
                    ? Icons.check_circle
                    : Icons.music_note_outlined,
              ),
              trailing: selected.containsKey(i)
                  ? IconButton(
                      tooltip: 'Desmarcar música',
                      onPressed: busy
                          ? null
                          : () => setState(() => selected.remove(i)),
                      icon: const Icon(Icons.close),
                    )
                  : const Icon(Icons.search),
              onTap: busy ? null : () => _choose(i),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: busy || selected.isEmpty ? null : _import,
              icon: const Icon(Icons.playlist_add),
              label: Text(
                'Salvar ${selected.length} de ${songs.length} músicas',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
