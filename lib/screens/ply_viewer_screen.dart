import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/ply_model.dart';
import '../services/api_service.dart';

/// Screen that downloads a PLY file from the server and renders it
/// as an interactive 3D view (rotate by dragging, pinch to zoom).
class PlyViewerScreen extends StatefulWidget {
  const PlyViewerScreen({
    super.key,
    required this.apiService,
    required this.uid,
  });

  final ApiService apiService;
  final String uid;

  @override
  State<PlyViewerScreen> createState() => _PlyViewerScreenState();
}

class _PlyViewerScreenState extends State<PlyViewerScreen> {
  PlyModel? _model;
  bool _loading = true;
  String? _error;

  double _rotX = 0.3; // radians
  double _rotY = 0.5;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _downloadAndParse();
  }

  Future<void> _downloadAndParse() async {
    try {
      final Uint8List bytes = await widget.apiService.downloadModel(widget.uid);
      final PlyModel model = PlyModel.parse(bytes);
      if (!mounted) return;
      setState(() {
        _model = model;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Model Viewer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading model:\n$_error',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : GestureDetector(
              onScaleUpdate: (ScaleUpdateDetails d) {
                setState(() {
                  if (d.pointerCount == 1) {
                    // Single finger drag → rotate
                    _rotY += d.focalPointDelta.dx * 0.01;
                    _rotX += d.focalPointDelta.dy * 0.01;
                  } else if (d.pointerCount == 2) {
                    // Pinch → zoom
                    _zoom = (_zoom * d.scale).clamp(0.1, 10.0);
                  }
                });
              },
              child: CustomPaint(
                size: Size.infinite,
                painter: _PlyPainter(
                  model: _model!,
                  rotX: _rotX,
                  rotY: _rotY,
                  zoom: _zoom,
                ),
              ),
            ),
    );
  }
}

/// Paints the PLY model using hardware-accelerated draw calls.
/// Point clouds use drawRawPoints; meshes use drawVertices.
class _PlyPainter extends CustomPainter {
  final PlyModel model;
  final double rotX;
  final double rotY;
  final double zoom;

  _PlyPainter({
    required this.model,
    required this.rotX,
    required this.rotY,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (model.vertices.isEmpty) return;

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double scale = min(size.width, size.height) * 0.4 * zoom;

    final bounds = model.bounds;

    final double sinX = sin(rotX), cosX = cos(rotX);
    final double sinY = sin(rotY), cosY = cos(rotY);

    final int vLen = model.vertices.length;

    // Build flat position list and colour list in one pass.
    final Float32List positions = Float32List(vLen * 2);
    final Int32List colors = Int32List(vLen);

    for (int i = 0; i < vLen; i++) {
      final PlyVertex v = model.vertices[i];
      double x = (v.x - bounds.cx) / bounds.extent;
      double y = (v.y - bounds.cy) / bounds.extent;
      double z = (v.z - bounds.cz) / bounds.extent;

      final double x1 = x * cosY + z * sinY;
      final double z1 = -x * sinY + z * cosY;
      final double y1 = y * cosX - z1 * sinX;

      positions[i * 2] = cx + x1 * scale;
      positions[i * 2 + 1] = cy - y1 * scale;
      colors[i] = v.color.value;
    }

    if (model.faces.isNotEmpty) {
      _drawMesh(canvas, positions, colors);
    } else {
      _drawPointCloud(canvas, positions, colors, vLen);
    }
  }

  void _drawMesh(Canvas canvas, Float32List positions, Int32List colors) {
    // Build triangle index list (fan-triangulate faces with > 3 verts).
    final List<int> triangles = <int>[];
    for (final PlyFace f in model.faces) {
      final List<int> idx = f.indices;
      if (idx.length < 3) continue;
      for (int j = 1; j < idx.length - 1; j++) {
        triangles.add(idx[0]);
        triangles.add(idx[j]);
        triangles.add(idx[j + 1]);
      }
    }

    final Uint16List indices = Uint16List.fromList(
      triangles.map((int i) => i.clamp(0, 65535)).toList(),
    );

    final ui.Vertices vertices = ui.Vertices.raw(
      VertexMode.triangles,
      positions,
      colors: colors,
      indices: indices,
    );

    // dstOver reliably shows per-vertex colours on all Flutter backends.
    canvas.drawVertices(vertices, BlendMode.dstOver, Paint());
    vertices.dispose();
  }

  void _drawPointCloud(
    Canvas canvas,
    Float32List positions,
    Int32List colors,
    int count,
  ) {
    // Render each point as a tiny screen-space triangle so we can use
    // drawVertices with per-vertex colour (fast, one GPU call).
    const double r = 1.5; // half-size of each point in pixels
    final Float32List triPos = Float32List(count * 6); // 3 verts * 2 coords
    final Int32List triCol = Int32List(count * 3); // 3 verts

    for (int i = 0; i < count; i++) {
      final double px = positions[i * 2];
      final double py = positions[i * 2 + 1];
      final int c = colors[i];
      final int base = i * 6;

      // Small equilateral triangle centred on (px, py).
      triPos[base] = px;
      triPos[base + 1] = py - r;
      triPos[base + 2] = px - r;
      triPos[base + 3] = py + r;
      triPos[base + 4] = px + r;
      triPos[base + 5] = py + r;

      final int cBase = i * 3;
      triCol[cBase] = c;
      triCol[cBase + 1] = c;
      triCol[cBase + 2] = c;
    }

    final ui.Vertices vertices = ui.Vertices.raw(
      VertexMode.triangles,
      triPos,
      colors: triCol,
    );

    canvas.drawVertices(vertices, BlendMode.dstOver, Paint());
    vertices.dispose();
  }

  @override
  bool shouldRepaint(covariant _PlyPainter old) =>
      rotX != old.rotX ||
      rotY != old.rotY ||
      zoom != old.zoom ||
      model != old.model;
}
