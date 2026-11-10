// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_preferences.dart';
import 'diagnostics_service.dart';
import 'update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.preferences,
    required this.updates,
    this.onSpotify,
  });
  final AppPreferences preferences;
  final UpdateService updates;
  final VoidCallback? onSpotify;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppVersion? installed;
  ReleaseInfo? available;
  bool checking = false;
  String? status;
  bool readingDiagnostics = false;

  Future<void> _copyDiagnostics(String report) async {
    try {
      await Clipboard.setData(ClipboardData(text: report));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Diagnóstico copiado.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível copiar o diagnóstico.'),
          ),
        );
      }
    }
  }

  Future<void> _diagnostics() async {
    setState(() => readingDiagnostics = true);
    try {
      final report = await const DiagnosticsService().read();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Diagnóstico local'),
          scrollable: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Versão, modelo do celular e registros de falhas. Nada é enviado automaticamente. Após um fechamento, copie este relatório para ajudar na correção.',
              ),
              const SizedBox(height: 16),
              SelectableText(report, style: const TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
            FilledButton.icon(
              onPressed: () => _copyDiagnostics(report),
              icon: const Icon(Icons.copy),
              label: const Text('Copiar'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível ler o diagnóstico. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => readingDiagnostics = false);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.updates
        .installed()
        .then((value) {
          if (mounted) setState(() => installed = value);
        })
        .catchError((Object _) {
          if (mounted) {
            setState(
              () => status = 'Não foi possível identificar a versão instalada.',
            );
          }
        });
  }

  Future<void> _save(Future<void> action) async {
    try {
      await action;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar as configurações. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _check() async {
    setState(() {
      checking = true;
      available = null;
      status = null;
    });
    try {
      final local = installed ?? await widget.updates.installed();
      final release = await widget.updates.check();
      if (!mounted) return;
      setState(() {
        installed = local;
        if (release == null) {
          status = 'Nenhuma versão publicada no momento.';
        } else if (release.version.newerThan(local)) {
          available = release;
          status = 'MusicON ${release.version.name} disponível!';
        } else {
          status = 'Seu MusicON está atualizado.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => status = e is StateError
              ? e.message.toString()
              : 'Não foi possível conectar ao GitHub. Verifique a internet e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configurações')),
    body: ListenableBuilder(
      listenable: widget.preferences,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Seu MusicON, suas cores.',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Escolha a cor que combina com seu momento.'),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: MusicColor.values
                .map(
                  (value) => ChoiceChip(
                    label: Text(value.label),
                    avatar: CircleAvatar(
                      backgroundColor: value.color,
                      radius: 9,
                    ),
                    selected: widget.preferences.color == value,
                    onSelected: (_) =>
                        _save(widget.preferences.setColor(value)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 20),
          if (widget.onSpotify != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.queue_music),
              title: const Text('Spotify'),
              subtitle: const Text('Conectar conta e importar playlists'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onSpotify,
            ),
          const Text(
            'Atualizações',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            installed == null
                ? 'Consultando versão instalada…'
                : 'MusicON ${installed!.name} • versão ${installed!.build}',
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Verificar ao abrir o app'),
            subtitle: const Text(
              'Avise quando houver uma nova versão no GitHub.',
            ),
            value: widget.preferences.autoUpdates,
            onChanged: (value) =>
                _save(widget.preferences.setAutoUpdates(value)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: checking ? null : _check,
            icon: checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_rounded),
            label: Text(checking ? 'Buscando…' : 'Buscar atualizações'),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(status!, semanticsLabel: status),
            ),
          if (available != null)
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await widget.updates.openDownload(available!.download);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Não foi possível abrir o download.'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Baixar nova versão'),
            ),
          const SizedBox(height: 16),
          const Text(
            'A nova versão abre no navegador. Depois do download, o Android orienta a instalação. Suas músicas e playlists continuam salvas ao atualizar.',
          ),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Diagnóstico de problemas'),
            subtitle: const Text(
              'Copiar informações após um fechamento inesperado',
            ),
            onTap: readingDiagnostics ? null : _diagnostics,
          ),
        ],
      ),
    ),
  );
}
