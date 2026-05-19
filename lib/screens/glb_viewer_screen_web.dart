import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:flutter/material.dart';

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
  String? _error;
  bool _loading = true;
  String? _viewType;
  html.DivElement? _container;
  html.FileUploadInputElement? _fileInput;
  String? _objectUrl;

  @override
  void initState() {
    super.initState();
    _viewType = 'glb-viewer-${widget.uid}-${DateTime.now().microsecondsSinceEpoch}';
    _setupHtmlView();
    _loadRemoteGlb();
  }

  @override
  void dispose() {
    _revokeObjectUrl();
    super.dispose();
  }

  void _setupHtmlView() {
    _container = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.background = '#000'
      ..setInnerHtml(
        '''
<script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/4.2.0/model-viewer.min.js"></script>
<model-viewer id="flutter-glb-viewer"
  style="width:100%;height:100%;background:#000;"
  alt="GLB model"
  camera-controls
  auto-rotate
  exposure="1.0"
  ar
  shadow-intensity="1"
  touch-action="pan-y"
></model-viewer>
''',
        treeSanitizer: html.NodeTreeSanitizer.trusted,
      );

    final dynamic registry = js_util.getProperty(html.window, 'platformViewRegistry');
    if (registry != null) {
      js_util.callMethod(
        registry,
        'registerViewFactory',
        [_viewType!, js_util.allowInterop((int viewId) => _container!)],
      );
    }
  }

  Future<void> _loadRemoteGlb() async {
    try {
      final Uint8List bytes = await widget.apiService.downloadModel(
        widget.uid,
        fileFormat: 'glb',
      );
      if (!mounted) return;
      _setModelSource('data:model/gltf-binary;base64,${base64Encode(bytes)}');
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Remote GLB load failed. Please upload a local GLB file.';
      });
    }
  }

  void _setModelSource(String src) {
    final html.Element? viewer = _container?.querySelector('#flutter-glb-viewer');
    if (viewer != null) {
      viewer.setAttribute('src', src);
    }
  }

  void _selectLocalFile() {
    _fileInput ??= html.FileUploadInputElement()
      ..accept = '.glb,.gltf'
      ..multiple = false
      ..onChange.listen((_) {
        final files = _fileInput?.files;
        if (files == null || files.isEmpty) return;
        final html.File file = files.first;
        _revokeObjectUrl();
        _objectUrl = html.Url.createObjectUrl(file);
        _setModelSource(_objectUrl!);
        if (!mounted) return;
        setState(() {
          _error = null;
        });
      });
    _fileInput?.click();
  }

  void _revokeObjectUrl() {
    if (_objectUrl != null) {
      html.Url.revokeObjectUrl(_objectUrl!);
      _objectUrl = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GLB Viewer')),
      body: Column(
        children: <Widget>[
          if (_loading)
            const LinearProgressIndicator()
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                ElevatedButton(
                  onPressed: _selectLocalFile,
                  child: const Text('Upload GLB file'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can upload a local GLB file and preview it directly in the browser.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: HtmlElementView(viewType: _viewType!),
          ),
        ],
      ),
    );
  }
}
