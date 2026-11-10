// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'audio_engine.dart';
import 'newpipe_prototype.dart';
import 'ui.dart' show accent, ink, muted, panel;

class MusicDiscoveryView extends StatelessWidget {
  const MusicDiscoveryView({
    super.key,
    required this.state,
    required this.input,
    required this.scroll,
  });
  final PrototypeController state;
  final TextEditingController input;
  final ScrollController scroll;

  Future<void> _search(BuildContext context) async {
    FocusScope.of(context).unfocus();
    await state.search(input.text);
    if (context.mounted && scroll.hasClients) {
      await scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = state.engine;
    final busy = state.searching || state.resolving || engine.busy;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: ink, size: 22),
            ),
            const SizedBox(width: 10),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Music',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(
                    text: 'ON',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 25, letterSpacing: -1),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          controller: scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DESCUBRA SEU PRÓXIMO SOM',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Dê play no seu mundo.',
                      style: TextStyle(
                        fontSize: 27,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Suas músicas. Seu momento.',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      key: const Key('query'),
                      controller: input,
                      textInputAction: TextInputAction.search,
                      onSubmitted: busy ? null : (_) => _search(context),
                      decoration: InputDecoration(
                        hintText: 'Música, artista ou link',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Buscar',
                          onPressed: busy ? null : () => _search(context),
                          icon: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: ink,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (busy)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const LinearProgressIndicator(minHeight: 2),
                            const SizedBox(height: 8),
                            Text(
                              state.searching
                                  ? 'Encontrando seu som…'
                                  : 'Preparando a música…',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (state.error ?? engine.error case final String message)
                      Container(
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34282B),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Color(0xFFFFD3B7),
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (state.results.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Encontradas para você',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${state.results.length} faixas',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                sliver: SliverList.builder(
                  itemCount: state.results.length,
                  itemBuilder: (context, index) {
                    final result = state.results[index];
                    final selected = engine.current?.originUrl == result.url;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Material(
                        color: selected
                            ? const Color(0xFF272033)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: busy
                              ? null
                              : () {
                                  FocusScope.of(context).unfocus();
                                  state.play(result);
                                },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                SongArtwork(url: result.artwork, size: 60),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        result.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.3,
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? accent
                                              : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        result.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  selected && engine.playing
                                      ? Icons.graphic_eq_rounded
                                      : Icons.play_arrow_rounded,
                                  color: selected ? accent : Colors.white54,
                                  size: 23,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (!busy && state.error == null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF292039), panel],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .06),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.headphones_rounded, color: accent, size: 38),
                      SizedBox(height: 20),
                      Text(
                        'Qual é a sua vibe hoje?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Busque aquela música que não sai da cabeça ou descubra um novo artista.',
                        style: TextStyle(
                          color: muted,
                          height: 1.6,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: engine.current == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: _NowPlaying(engine: engine),
              ),
            ),
    );
  }
}

class SongArtwork extends StatelessWidget {
  const SongArtwork({super.key, required this.url, this.size = 60});
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url ?? '');
    final valid =
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF574077), Color(0xFF28203A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.album_rounded, color: accent, size: size * .46),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: valid
            ? Image.network(
                uri.toString(),
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                excludeFromSemantics: true,
                frameBuilder: (_, child, frame, _) =>
                    frame == null ? placeholder : child,
                errorBuilder: (_, _, _) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.engine});
  final MusicEngine engine;
  String _time(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final track = engine.current!;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF272032),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .16)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SongArtwork(url: track.artworkUrl, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOCANDO AGORA',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: engine.playing ? 'Pausar' : 'Continuar',
                onPressed: engine.busy ? null : engine.toggle,
                style: IconButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: ink,
                ),
                icon: Icon(
                  engine.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 2,
              value: engine.duration.inMilliseconds > 0
                  ? (engine.position.inMilliseconds /
                            engine.duration.inMilliseconds)
                        .clamp(0, 1)
                  : 0,
              backgroundColor: Colors.white10,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _time(engine.position),
                style: const TextStyle(fontSize: 10, color: muted),
              ),
              Text(
                _time(engine.duration),
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
