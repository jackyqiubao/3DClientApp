import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/api_service.dart';

class UsdzViewerScreen extends StatefulWidget {
  const UsdzViewerScreen({
    super.key,
    required this.apiService,
    required this.uid,
  });

  final ApiService apiService;
  final String uid;

  @override
  State<UsdzViewerScreen> createState() => _UsdzViewerScreenState();
}

class _UsdzViewerScreenState extends State<UsdzViewerScreen> {
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

    _loadUsdZ();
  }

  Future<void> _loadUsdZ() async {
    try {
      final Uint8List bytes = await widget.apiService.downloadModel(
        widget.uid,
        fileFormat: 'usdz',
      );

      if (!mounted) return;
      if (kIsWeb) {
        setState(() {
          _error = 'USDZ rendering is not supported in web browser fallback.';
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
      src="data:model/vnd.usdz+zip;base64,$base64Data"
      alt="USDZ model"
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
      appBar: AppBar(title: const Text('USDZ Viewer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Unable to render USDZ:\n$_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _controller == null
                  ? const Center(
                      child: Text('USDZ rendering is not available on this platform.'),
                    )
                  : WebViewWidget(controller: _controller!),
    );
  }
}
