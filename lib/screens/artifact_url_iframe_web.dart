import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';


class ArtifactUrlIframe extends StatefulWidget {
  const ArtifactUrlIframe({
    super.key,
    required this.url,
  });

  final String url;

  @override
  State<ArtifactUrlIframe> createState() => _ArtifactUrlIframeState();
}

class _ArtifactUrlIframeState extends State<ArtifactUrlIframe> {
  String? _viewType;
  html.DivElement? _container;

  @override
  void initState() {
    super.initState();
    _viewType = 'artifact-url-iframe-${DateTime.now().microsecondsSinceEpoch}';
    _setupHtmlView();
  }

  void _setupHtmlView() {
    final html.IFrameElement iframe = html.IFrameElement()
      ..src = widget.url
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'fullscreen'
      ..allowFullscreen = true;

    _container = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..append(iframe);

    final dynamic registry = js_util.getProperty(html.window, 'platformViewRegistry');
    if (registry != null) {
      js_util.callMethod(
        registry,
        'registerViewFactory',
        [_viewType!, js_util.allowInterop((int viewId) => _container!)],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SelectableText(
            widget.url,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        Row(
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                html.window.open(widget.url, '_blank');
              },
              child: const Text('Open in new tab'),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'If the iframe does not load, the server may be blocking framing or mixed-content.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          width: double.infinity,
          child: HtmlElementView(viewType: _viewType!),
        ),
      ],
    );
  }
}
