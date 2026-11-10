import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'audio_engine.dart';
import 'app_preferences.dart';
import 'settings_page.dart';
import 'update_service.dart';
import 'newpipe_prototype.dart';
import 'music_discovery_view.dart' show SongArtwork;
import 'library_controller.dart';
import 'models.dart';
import 'online_services.dart';
import 'explore/explorer_page.dart';
import 'explore/browser_page.dart';

const ink = Color(0xFF0D0C12);
const panel = Color(0xFF19171F);
const accent = Color(0xFFB79AFF);
const muted = Color(0xFFAAA6B8);
final musicTheme = musicThemeFor(accent);
ThemeData musicThemeFor(Color accent) => ThemeData(
  fontFamily: 'Roboto',
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: ink,
  colorScheme: ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
    surface: panel,
    primary: accent,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: ink,
    surfaceTintColor: Colors.transparent,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: panel,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: ink,
    indicatorColor: Color.lerp(ink, accent, .23),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
      textStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
);

class MusicOnApp extends StatelessWidget {
  const MusicOnApp({
    super.key,
    required this.library,
    required this.engine,
    this.services,
    this.discovery,
    this.preferences,
    this.updates,
  });
  final LibraryController library;
  final MusicEngine engine;
  final OnlineServices? services;
  final PrototypeController? discovery;
  final AppPreferences? preferences;
  final UpdateService? updates;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([?preferences]),
    builder: (context, _) => MaterialApp(
      title: 'MusicON',
      debugShowCheckedModeBanner: false,
      theme: musicThemeFor(preferences?.color.color ?? accent),
      home: MusicHome(
        library: library,
        engine: engine,
        services: services,
        discovery: discovery,
        preferences: preferences,
        updates: updates,
      ),
    ),
  );
}

class MusicHome extends StatefulWidget {
  const MusicHome({
    super.key,
    required this.library,
    required this.engine,
    this.services,
    this.discovery,
    this.preferences,
    this.updates,
  });
  final LibraryController library;
  final MusicEngine engine;
  final OnlineServices? services;
  final PrototypeController? discovery;
  final AppPreferences? preferences;
  final UpdateService? updates;
  @override
  State<MusicHome> createState() => _MusicHomeState();
}

class _MusicHomeState extends State<MusicHome> {
  late final OnlineServices services;
  int page = 0;
  int libraryTab = 0;
  int sourceFilter = 0;
  String query = '';
  final onlineInput = TextEditingController();
  String? lastError;
  LibraryController get library => widget.library;
  MusicEngine get engine => widget.engine;
  @override
  void initState() {
    super.initState();
    services = widget.services ?? OnlineServices.create(library);
    library.addListener(_onChange);
    engine.addListener(_onChange);
    widget.discovery?.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onChange();
      if (widget.preferences?.autoUpdates == true) _automaticUpdate();
    });
  }

  Future<void> _automaticUpdate() async {
    final updates = widget.updates;
    if (updates == null) return;
    try {
      final local = await updates.installed();
      final release = await updates.check();
      if (mounted && release != null && release.version.newerThan(local)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('MusicON ${release.version.name} disponível.'),
            action: SnackBarAction(label: 'Ver', onPressed: _settings),
          ),
        );
      }
    } catch (_) {
      /* Manual check in settings shows network errors. */
    }
  }

  void _settings() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => SettingsPage(
        preferences: widget.preferences!,
        updates: widget.updates!,
      ),
    ),
  );

  void _onChange() {
    if (!mounted) return;
    final error = engine.error ?? library.error ?? widget.discovery?.error;
    if (error != null && error != lastError) {
      lastError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _message(error);
      });
    }
    if (error == null) lastError = null;
    setState(() {});
  }

  @override
  void dispose() {
    library.removeListener(_onChange);
    engine.removeListener(_onChange);
    widget.discovery?.removeListener(_onChange);
    onlineInput.dispose();
    if (widget.services == null) services.dispose();
    super.dispose();
  }

  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
  Future<void> _import() async {
    final count = await library.importAudio();
    if (!mounted) return;
    if (count > 0) _message('$count música(s) adicionada(s) ao aparelho.');
  }

  void _addMusic() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aumente o volume da sua coleção',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: Icon(
                Icons.phone_android_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text('Importar do celular'),
              subtitle: Text('Escolha arquivos de áudio para ouvir offline'),
              onTap: () {
                Navigator.pop(context);
                _import();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.link_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text('Adicionar link online'),
              subtitle: Text(
                widget.discovery == null
                    ? 'Analisar um link ou buscar músicas no Jamendo'
                    : 'Encontre músicas e artistas para sua coleção',
              ),
              onTap: () {
                Navigator.pop(context);
                _onlineDialog();
              },
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _onlineDialog() async {
    setState(() => page = widget.discovery == null ? 2 : 1);
  }

  Future<MusicPlaylist?> _createPlaylist() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const PlaylistDialog(),
    );
    if (name == null) return null;
    return library.createPlaylist(name);
  }

  Future<bool> _remember(Track track) async {
    if (library.findTrack(track.id) != null) return true;
    try {
      await library.addResolved(track);
      return true;
    } catch (_) {
      if (mounted) {
        _message('Não foi possível salvar a música. Tente novamente.');
      }
      return false;
    }
  }

  Future<void> _favorite(Track track) async {
    if (await _remember(track)) await library.toggleFavorite(track);
  }

  Future<void> _playCollection(
    List<Track> tracks, {
    required bool random,
  }) async {
    if (engine.busy || tracks.isEmpty) return;
    if (engine.shuffle != random) await engine.toggleShuffle();
    await engine.playQueue(
      tracks,
      random ? math.Random().nextInt(tracks.length) : 0,
    );
  }

  Future<void> _addToPlaylist(Track track) async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Adicionar à playlist',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(Icons.add_rounded),
              title: Text('Criar nova playlist'),
              onTap: () => Navigator.pop(context, 'new'),
            ),
            ...library.playlists.map(
              (p) => ListTile(
                leading: Icon(Icons.queue_music_rounded),
                title: Text(p.name),
                onTap: () => Navigator.pop(context, p.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (selection == null || !mounted) return;
    final playlist = selection == 'new'
        ? await _createPlaylist()
        : library.playlists.firstWhere((p) => p.id == selection);
    if (playlist == null) return;
    if (!await _remember(track)) return;
    await library.addToPlaylist(playlist, track);
    if (mounted) _message('Adicionada a ${playlist.name}.');
  }

  void _openPlayer() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ink,
    builder: (_) => PlayerSheet(engine: engine, library: library),
  );
  void _openPlaylist(MusicPlaylist playlist) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final tracks = library.playlistTracks(playlist);
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        playlist.name,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Tocar em sequência',
                      onPressed: tracks.isEmpty || engine.busy
                          ? null
                          : () {
                              _playCollection(tracks, random: false);
                              Navigator.pop(context);
                            },
                      icon: Icon(Icons.play_arrow_rounded),
                    ),
                    IconButton(
                      tooltip: 'Tocar aleatório',
                      onPressed: tracks.isEmpty || engine.busy
                          ? null
                          : () {
                              _playCollection(tracks, random: true);
                              Navigator.pop(context);
                            },
                      icon: Icon(Icons.shuffle_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tracks.isEmpty
                    ? const EmptyState(
                        icon: Icons.queue_music_rounded,
                        title: 'Essa playlist é toda sua',
                        detail:
                            'Use o menu de uma música para adicioná-la aqui.',
                      )
                    : ListView.builder(
                        itemCount: tracks.length,
                        itemBuilder: (context, i) => ListTile(
                          leading: CoverArt(
                            color: tracks[i].color,
                            size: 48,
                            artwork: tracks[i].artworkUrl,
                          ),
                          title: Text(tracks[i].title),
                          subtitle: Text(tracks[i].sourceLabel),
                          onTap: () => engine.playQueue(tracks, i),
                          trailing: IconButton(
                            tooltip: 'Retirar da playlist',
                            icon: Icon(Icons.remove_circle_outline),
                            onPressed: () =>
                                library.removeFromPlaylist(playlist, tracks[i]),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        color: ink,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Music',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          TextSpan(
                            text: 'ON',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      style: TextStyle(fontSize: 24, letterSpacing: -1),
                    ),
                    const Spacer(),
                    if (widget.preferences != null && widget.updates != null)
                      IconButton(
                        tooltip: 'Configurações',
                        onPressed: _settings,
                        icon: Icon(Icons.settings_rounded),
                      ),
                    IconButton(
                      tooltip: 'Adicionar música',
                      onPressed: library.importing ? null : _addMusic,
                      icon: library.importing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (page) {
                  0 => _home(),
                  1 => widget.discovery == null ? _search() : _onlineSearch(),
                  2 => ExplorerPage(
                    services: services,
                    library: library,
                    engine: engine,
                  ),
                  _ => _library(),
                },
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (engine.current != null) _miniPlayer(),
        NavigationBar(
          selectedIndex: widget.discovery != null && page == 3 ? 2 : page,
          onDestinationSelected: (value) => setState(
            () => page = widget.discovery != null && value == 2 ? 3 : value,
          ),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Início',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              label: 'Buscar',
            ),
            if (widget.discovery == null)
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Explorar',
              ),
            NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music_rounded),
              label: 'Biblioteca',
            ),
          ],
        ),
      ],
    ),
  );

  Widget _home() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    children: [
      Text(
        'SINTONIZE O SEU MOMENTO',
        style: TextStyle(
          color: muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Dê play no seu mundo.',
        style: TextStyle(
          fontSize: 29,
          height: 1.12,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 24),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).colorScheme.primary == accent
                ? [
                    const Color(0xFF45306E),
                    const Color(0xFF231C3B),
                    const Color(0xFF191726),
                  ]
                : [
                    Color.lerp(
                      ink,
                      Theme.of(context).colorScheme.primary,
                      .42,
                    )!,
                    Color.lerp(ink, Theme.of(context).colorScheme.primary, .2)!,
                    panel,
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -48,
              top: -16,
              child: Opacity(
                opacity: .55,
                child: CoverArt(
                  color: 0,
                  size: 240,
                  round: true,
                  tint: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SEU SOM, SEM LIMITES',
                    style: TextStyle(
                      color: Color(0xFFDBCCFF),
                      fontSize: 10,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sua música.\nSeu universo.',
                    style: TextStyle(
                      fontSize: 34,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No celular ou na nuvem.\nSempre no seu ritmo.',
                    style: TextStyle(
                      color: Color(0xFFD8D0E8),
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: engine.busy
                        ? null
                        : () => engine.playQueue(demoTracks, 0),
                    icon: Icon(Icons.play_arrow_rounded),
                    label: Text('Experimentar o som'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: _shortcut(
              Icons.phone_android_rounded,
              'Do celular',
              'Seu som offline',
              () {
                setState(() {
                  page = 3;
                  libraryTab = 0;
                  sourceFilter = 1;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _shortcut(
              Icons.language_rounded,
              'Online',
              'Além da sua coleção',
              () {
                setState(() {
                  page = 3;
                  libraryTab = 0;
                  sourceFilter = 2;
                });
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Text(
        'Descubra o MusicON',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -.5,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Três demos originais para entrar no clima.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 18),
      SizedBox(
        height: 226,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: demoTracks.length,
          separatorBuilder: (_, _) => const SizedBox(width: 16),
          itemBuilder: (context, i) {
            final track = demoTracks[i];
            return SizedBox(
              width: 138,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => engine.playQueue(demoTracks, i),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CoverArt(color: track.color, size: 138),
                    const SizedBox(height: 10),
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'MusicON Lab • demo',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.headphones_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Sua coleção merece um lugar.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Importe suas faixas e leve suas playlists com você.',
              style: TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: library.importing ? null : _import,
              icon: Icon(Icons.add_rounded),
              label: Text('Adicionar minhas músicas'),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _shortcut(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Material(
    color: panel,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 23),
            const SizedBox(height: 14),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: muted, fontSize: 10)),
          ],
        ),
      ),
    ),
  );

  Widget _onlineSearch() {
    final discovery = widget.discovery!;
    final tracks = discovery.results
        .map(
          (v) => Track(
            id: 'youtube-${v.url}',
            title: v.title,
            artist: v.artist,
            location: v.url,
            originUrl: v.url,
            artworkUrl: v.artwork,
            source: TrackSource.online,
            providerId: 'youtube',
          ),
        )
        .toList();
    Future<void> search() async {
      FocusScope.of(context).unfocus();
      final value = onlineInput.text.trim();
      await discovery.search(value);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Text(
            'Encontre seu próximo play.',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            key: const Key('online-query'),
            controller: onlineInput,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => search(),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Música, artista ou link',
              suffixIcon: IconButton(
                tooltip: 'Buscar online',
                onPressed: discovery.searching ? null : search,
                icon: Icon(Icons.arrow_forward),
              ),
            ),
          ),
        ),
        if (discovery.searching)
          const Padding(
            padding: EdgeInsets.all(24),
            child: LinearProgressIndicator(),
          ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tracks.isEmpty
                ? 'DESCUBRA SEU PRÓXIMO SOM'
                : '${tracks.length} MÚSICAS ENCONTRADAS',
            style: TextStyle(color: muted, fontSize: 10, letterSpacing: 2),
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? const EmptyState(
                  icon: Icons.travel_explore,
                  title: 'Um mundo de músicas',
                  detail:
                      'Busque uma faixa e guarde suas descobertas nos favoritos ou em uma playlist.',
                )
              : _trackList(tracks),
        ),
      ],
    );
  }

  Widget _search() {
    final normalized = query.trim().toLowerCase();
    final tracks = library.tracks
        .where(
          (t) => '${t.title} ${t.artist}'.toLowerCase().contains(normalized),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Text(
            'Encontre seu próximo play.',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Músicas ou artistas da biblioteca',
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'NA SUA BIBLIOTECA',
            style: TextStyle(color: muted, fontSize: 10, letterSpacing: 2),
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Nenhuma faixa por aqui',
                  detail: 'Tente outro nome ou adicione músicas à biblioteca.',
                )
              : _trackList(tracks),
        ),
      ],
    );
  }

  Widget _library() {
    final tracks = library.tracks
        .where((t) => libraryTab != 1 || library.isFavorite(t))
        .where(
          (t) =>
              sourceFilter == 0 ||
              (sourceFilter == 1
                  ? t.source != TrackSource.online
                  : t.source == TrackSource.online),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 16, 14),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Sua biblioteca',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Criar playlist',
                onPressed: _createPlaylist,
                icon: Icon(Icons.playlist_add_rounded),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(['Músicas', 'Favoritas', 'Playlists'][i]),
                    selected: libraryTab == i,
                    onSelected: (_) => setState(() => libraryTab = i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (libraryTab != 2)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: DropdownButton<int>(
              value: sourceFilter,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Todas as fontes')),
                DropdownMenuItem(value: 1, child: Text('Disponíveis offline')),
                DropdownMenuItem(value: 2, child: Text('Músicas online')),
              ],
              onChanged: (value) => setState(() => sourceFilter = value!),
            ),
          ),
        if (libraryTab != 2 && tracks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: engine.busy
                      ? null
                      : () => _playCollection(tracks, random: false),
                  icon: Icon(Icons.play_arrow),
                  label: Text('Em sequência'),
                ),
                TextButton.icon(
                  onPressed: engine.busy
                      ? null
                      : () => _playCollection(tracks, random: true),
                  icon: Icon(Icons.shuffle),
                  label: Text('Aleatório'),
                ),
              ],
            ),
          ),
        Expanded(
          child: libraryTab == 2
              ? _playlists()
              : tracks.isEmpty
              ? EmptyState(
                  icon: libraryTab == 1
                      ? Icons.favorite_border
                      : Icons.library_music_outlined,
                  title: libraryTab == 1
                      ? 'Guarde o que você ama'
                      : 'Seu próximo som começa aqui',
                  detail: libraryTab == 1
                      ? 'Toque no coração de uma música para encontrá-la aqui.'
                      : 'Adicione um link de áudio para ouvir pela internet.',
                  action: libraryTab == 1
                      ? null
                      : FilledButton.icon(
                          onPressed: _onlineDialog,
                          icon: Icon(Icons.add_link),
                          label: Text('Adicionar link'),
                        ),
                )
              : _trackList(tracks),
        ),
      ],
    );
  }

  Widget _playlists() => library.playlists.isEmpty
      ? EmptyState(
          icon: Icons.queue_music_rounded,
          title: 'Uma playlist para cada momento',
          detail: 'Misture suas faixas locais e online em uma coleção só.',
          action: FilledButton.icon(
            onPressed: _createPlaylist,
            icon: Icon(Icons.add),
            label: Text('Criar playlist'),
          ),
        )
      : ListView(
          children: library.playlists
              .map(
                (p) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        ink,
                        Theme.of(context).colorScheme.primary,
                        .23,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.queue_music_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(p.name),
                  subtitle: Text('${p.trackIds.length} faixas'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => _openPlaylist(p),
                ),
              )
              .toList(),
        );

  Widget _trackList(List<Track> tracks) => ListView.builder(
    padding: const EdgeInsets.only(bottom: 24),
    itemCount: tracks.length,
    itemBuilder: (context, i) {
      final track = tracks[i];
      final selected = engine.current?.id == track.id;
      return ListTile(
        contentPadding: const EdgeInsets.only(left: 24, right: 8),
        leading: CoverArt(
          color: track.color,
          size: 50,
          artwork: track.artworkUrl,
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${track.artist} · ${track.sourceLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: muted, fontSize: 11),
        ),
        onTap: engine.busy ? null : () => engine.playQueue(tracks, i),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: library.isFavorite(track)
                  ? 'Remover dos favoritos'
                  : 'Favoritar',
              onPressed: () => _favorite(track),
              icon: Icon(
                library.isFavorite(track)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: library.isFavorite(track)
                    ? Theme.of(context).colorScheme.primary
                    : muted,
                size: 21,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opções da música',
              iconSize: 21,
              onSelected: (action) async {
                if (action == 'source') {
                  if (engine.playing) await engine.toggle();
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          BrowserPage(initialUri: Uri.parse(track.originUrl!)),
                    ),
                  );
                } else {
                  _addToPlaylist(track);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'playlist',
                  child: Text('Adicionar à playlist'),
                ),
                if (Uri.tryParse(track.originUrl ?? '')?.scheme == 'https')
                  const PopupMenuItem(
                    value: 'source',
                    child: Text('Abrir fonte da música'),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
  Widget _miniPlayer() {
    final track = engine.current!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: Color.lerp(ink, Theme.of(context).colorScheme.primary, .18),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openPlayer,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
                child: Row(
                  children: [
                    CoverArt(
                      color: track.color,
                      size: 42,
                      artwork: track.artworkUrl,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    PlayButton(engine: engine, compact: true),
                    IconButton(
                      tooltip: 'Próxima faixa',
                      onPressed: engine.hasNext ? engine.next : null,
                      icon: Icon(Icons.skip_next_rounded),
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                value: engine.duration.inMilliseconds == 0
                    ? 0
                    : (engine.position.inMilliseconds /
                              engine.duration.inMilliseconds)
                          .clamp(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerSheet extends StatelessWidget {
  const PlayerSheet({super.key, required this.engine, required this.library});
  final MusicEngine engine;
  final LibraryController library;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([engine, library]),
    builder: (context, _) {
      final track = engine.current;
      if (track == null) return const SizedBox.shrink();
      final total = engine.duration.inMilliseconds.toDouble();
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * .92,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Fechar player',
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                        const Expanded(
                          child: Text(
                            'AGORA NO SEU MUNDO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, c) => CoverArt(
                        color: track.color,
                        artwork: track.artworkUrl,
                        size: math.min(c.maxWidth, 350),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                style: TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.7,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                track.artist,
                                style: TextStyle(color: muted, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: library.isFavorite(track)
                              ? 'Remover dos favoritos'
                              : 'Favoritar',
                          onPressed: () => library.toggleFavorite(track),
                          icon: Icon(
                            library.isFavorite(track)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Slider(
                      value: engine.position.inMilliseconds.toDouble().clamp(
                        0,
                        math.max(total, 1),
                      ),
                      max: math.max(total, 1),
                      onChanged: total > 0
                          ? (value) => engine.seek(
                              Duration(milliseconds: value.round()),
                            )
                          : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatTime(engine.position),
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                        Text(
                          formatTime(engine.duration),
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: engine.shuffle
                              ? 'Desativar aleatório'
                              : 'Ativar aleatório',
                          onPressed: engine.toggleShuffle,
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: engine.shuffle
                                ? Theme.of(context).colorScheme.primary
                                : muted,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Faixa anterior',
                          onPressed: engine.hasPrevious
                              ? engine.previous
                              : null,
                          iconSize: 34,
                          icon: Icon(Icons.skip_previous_rounded),
                        ),
                        PlayButton(engine: engine),
                        IconButton(
                          tooltip: 'Próxima faixa',
                          onPressed: engine.hasNext ? engine.next : null,
                          iconSize: 34,
                          icon: Icon(Icons.skip_next_rounded),
                        ),
                        IconButton(
                          tooltip: engine.repeat
                              ? 'Desativar repetição'
                              : 'Repetir fila',
                          onPressed: engine.toggleRepeat,
                          icon: Icon(
                            Icons.repeat_rounded,
                            color: engine.repeat
                                ? Theme.of(context).colorScheme.primary
                                : muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          track.source == TrackSource.online
                              ? Icons.language
                              : Icons.offline_pin_outlined,
                          size: 15,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          track.sourceLabel,
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                    if (engine.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          engine.error!,
                          style: TextStyle(color: Color(0xFFFFB4AB)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class PlayButton extends StatelessWidget {
  const PlayButton({super.key, required this.engine, this.compact = false});
  final MusicEngine engine;
  final bool compact;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: compact ? 44 : 72,
    height: compact ? 44 : 72,
    child: engine.busy
        ? const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : IconButton.filled(
            tooltip: engine.playing ? 'Pausar' : 'Reproduzir',
            onPressed: engine.toggle,
            iconSize: compact ? 25 : 42,
            style: IconButton.styleFrom(
              backgroundColor: compact
                  ? Colors.transparent
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: compact ? Colors.white : ink,
            ),
            icon: Icon(
              engine.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
          ),
  );
}

class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.color,
    required this.size,
    this.round = false,
    this.artwork,
    this.tint,
  });
  final int color;
  final double size;
  final bool round;
  final String? artwork;
  final Color? tint;
  @override
  Widget build(BuildContext context) => artwork != null
      ? SongArtwork(url: artwork, size: size)
      : ClipRRect(
          borderRadius: BorderRadius.circular(round ? size : size * .13),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _CoverPainter(color, tint)),
          ),
        );
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.variant, this.tint);
  final Color? tint;
  final int variant;
  @override
  void paint(Canvas canvas, Size size) {
    const palettes = [
      [Color(0xFF462A79), Color(0xFFB7A1F0), Color(0xFF271A42)],
      [Color(0xFF123C49), Color(0xFF80D9CB), Color(0xFF192B39)],
      [Color(0xFF65344E), Color(0xFFF2B8A3), Color(0xFF342037)],
    ];
    final colors = tint == null || tint == accent
        ? palettes[variant % palettes.length]
        : [Color.lerp(ink, tint, .48)!, tint!, Color.lerp(ink, tint, .22)!];
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors[0], colors[2]],
        ).createShader(rect),
    );
    final center = Offset(size.width * .52, size.height * .48);
    final radius = size.width * .34;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.6, -.7),
          colors: [colors[1], colors[0], colors[2]],
          stops: const [0, .65, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    for (var i = 0; i < 9; i++) {
      final paint = Paint()
        ..color = colors[1].withValues(alpha: .12 + .035 * i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .003;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-.5);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * (.58 + i * .04),
          height: size.height * (.12 + i * .037),
        ),
        paint,
      );
      canvas.restore();
    }
    final star = Paint()..color = colors[1].withValues(alpha: .8);
    canvas.drawCircle(
      Offset(size.width * .19, size.height * .18),
      size.width * .011,
      star,
    );
    canvas.drawCircle(
      Offset(size.width * .85, size.height * .78),
      size.width * .007,
      star,
    );
    for (var i = 0; i < 14; i++) {
      final h = (math.sin(i * .85).abs() * .065 + .015) * size.height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * .15 + i * size.width * .052,
            size.height * .86 - h / 2,
            size.width * .017,
            h,
          ),
          const Radius.circular(8),
        ),
        Paint()..color = colors[1].withValues(alpha: .6),
      );
    }
  }

  @override
  bool shouldRepaint(_CoverPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.tint != tint;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });
  final IconData icon;
  final String title, detail;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    ),
  );
}

class OnlineDialog extends StatefulWidget {
  const OnlineDialog({super.key});
  @override
  State<OnlineDialog> createState() => _OnlineDialogState();
}

class _OnlineDialogState extends State<OnlineDialog> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      artist = TextEditingController(),
      url = TextEditingController();
  @override
  void dispose() {
    title.dispose();
    artist.dispose();
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Adicionar faixa online'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cole um link HTTPS direto para áudio, como MP3 ou M4A. Links de páginas do Spotify ou YouTube não funcionam aqui.',
              style: TextStyle(color: muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: title,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Nome da música'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Informe um nome.'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: artist,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Artista (opcional)',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Link HTTPS do áudio',
              ),
              validator: (value) => validateAudioUrl(value ?? ''),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, (
              title: title.text,
              artist: artist.text,
              url: url.text,
            ));
          }
        },
        child: Text('Adicionar'),
      ),
    ],
  );
}

class PlaylistDialog extends StatefulWidget {
  const PlaylistDialog({super.key});
  @override
  State<PlaylistDialog> createState() => _PlaylistDialogState();
}

class _PlaylistDialogState extends State<PlaylistDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Nova playlist'),
    content: TextField(
      controller: controller,
      autofocus: true,
      maxLength: 60,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(labelText: 'Dê um nome ao seu momento'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancelar'),
      ),
      FilledButton(
        onPressed: controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, controller.text.trim()),
        child: Text('Criar'),
      ),
    ],
  );
}
