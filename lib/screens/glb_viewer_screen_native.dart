import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/api_service.dart';

class GlbViewerScreen extends StatefulWidget {
  const GlbViewerScreen({
    super.key,
    required this.apiService,
    required this.uid,
  });

  final ApiService apiService;
  final String uid;

  @override
  State<GlbViewerScreen> createState() => _GlbViewerScreenState();
}

class _GlbViewerScreenState extends State<GlbViewerScreen> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      final PlatformWebViewControllerCreationParams params =
          const PlatformWebViewControllerCreationParams();
      _controller = WebViewController.fromPlatformCreationParams(params)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (WebResourceError error) {
              if (!mounted) return;
              setState(() {
                _error = error.description;
                _loading = false;
              });
            },
          ),
        );
    }

    _loadGlb();
  }

  Future<void> _loadGlb() async {
    try {
      final Uint8List bytes = await widget.apiService.downloadModel(
        widget.uid,
        fileFormat: 'glb',
      );

      if (!mounted) return;
      if (kIsWeb) {
        setState(() {
          _error = 'GLB rendering is not supported in web browser fallback.';
          _loading = false;
        });
        return;
      }

      final String html = _buildHtml(base64Encode(bytes));
      _controller?.loadHtmlString(html);

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _buildHtml(String base64Data) {
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <script type="module" src="https://unpkg.com/@google/model-viewer/dist/model-viewer.min.js"></script>
    <style>
      html, body {
        margin: 0;
        padding: 0;
        height: 100%;
        background: #000;
      }
      model-viewer {
        width: 100%;
        height: 100%;
      }
    </style>
  </head>
  <body>
    <model-viewer
      src="data:model/gltf-binary;base64,$base64Data"
      alt="GLB model"
      camera-controls
      auto-rotate
      exposure="1.0"
      ar
    ></model-viewer>
  </body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GLB Viewer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Unable to render GLB:\n$_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _controller == null
                  ? const Center(
                      child: Text('GLB rendering is not available on this platform.'),
                    )
                  : WebViewWidget(controller: _controller!),
    );
  }
}
