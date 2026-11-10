import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../sources/media_source.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key, required this.initialUri});
  final Uri initialUri;
  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> with WidgetsBindingObserver {
  WebViewController? controller;
  late Uri current;
  int progress = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    current = widget.initialUri;
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final view = WebViewController();
      await view.setJavaScriptMode(JavaScriptMode.unrestricted);
      await view.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            try {
              parseWebLink(request.url);
            } catch (_) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onProgress: (value) {
            if (mounted) setState(() => progress = value);
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                current = Uri.parse(url);
                error = null;
              });
            }
          },
          onUrlChange: (change) {
            final uri = Uri.tryParse(change.url ?? '');
            if (mounted && uri?.scheme == 'https') {
              setState(() => current = uri!);
            }
          },
          onWebResourceError: (failure) {
            if (mounted && failure.isForMainFrame == true) {
              setState(
                () => error =
                    'A página não carregou. Verifique a conexão e tente novamente.',
              );
            }
          },
        ),
      );
      if (!mounted) return;
      setState(() => controller = view);
      await view.loadRequest(widget.initialUri);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'O navegador não pôde iniciar. Verifique o Android System WebView no aparelho.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pauseMedia();
  }

  Future<void> _pauseMedia() async {
    try {
      await controller?.runJavaScript(
        'document.querySelectorAll("video,audio").forEach(function(m){m.pause();});',
      );
    } catch (_) {
      /* The page may already have been closed. */
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pauseMedia();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Navegador', style: TextStyle(fontSize: 17)),
          Text(
            current.host,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Recarregar página',
          onPressed: () async {
            setState(() => error = null);
            if (controller == null) {
              await _initialize();
            } else {
              await controller!.reload();
            }
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        if (progress < 100 && error == null)
          LinearProgressIndicator(value: progress / 100),
        Expanded(
          child: error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(error!, textAlign: TextAlign.center),
                  ),
                )
              : controller == null
              ? const Center(child: CircularProgressIndicator())
              : WebViewWidget(controller: controller!),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Página anterior',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    if (await controller?.canGoBack() == true) {
                      await controller!.goBack();
                    }
                  },
                ),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, current.toString()),
                    icon: const Icon(Icons.link),
                    label: const Text('Usar este link'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
