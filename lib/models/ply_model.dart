import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class PlyVertex {
  final double x, y, z;
  final Color color;

  const PlyVertex(this.x, this.y, this.z, this.color);
}

class PlyFace {
  final List<int> indices;

  const PlyFace(this.indices);
}

class PlyModel {
  final List<PlyVertex> vertices;
  final List<PlyFace> faces;

  PlyModel({required this.vertices, required this.faces});

  /// Parse a PLY file from raw bytes (supports ASCII and binary_little_endian).
  factory PlyModel.parse(Uint8List data) {
    // Find header end
    final String headerStr = _extractHeader(data);
    final List<String> headerLines = const LineSplitter()
        .convert(headerStr)
        .map((String l) => l.trim())
        .toList();

    String format = 'ascii';
    int vertexCount = 0;
    int faceCount = 0;
    final List<String> vertexProps = <String>[];

    bool inVertex = false;
    bool inFace = false;

    for (final String line in headerLines) {
      if (line.startsWith('format ')) {
        format = line.split(' ')[1];
      } else if (line.startsWith('element vertex')) {
        vertexCount = int.parse(line.split(' ').last);
        inVertex = true;
        inFace = false;
      } else if (line.startsWith('element face')) {
        faceCount = int.parse(line.split(' ').last);
        inVertex = false;
        inFace = true;
      } else if (line.startsWith('element ')) {
        inVertex = false;
        inFace = false;
      } else if (line.startsWith('property') && inVertex) {
        vertexProps.add(line);
      }
    }

    // Byte offset right after "end_header\n"
    final int headerEnd = _findHeaderEnd(data);

    if (format == 'ascii') {
      return _parseAscii(data, headerEnd, vertexCount, faceCount, vertexProps);
    } else if (format == 'binary_little_endian') {
      return _parseBinaryLE(
        data,
        headerEnd,
        vertexCount,
        faceCount,
        vertexProps,
      );
    } else {
      throw FormatException('Unsupported PLY format: $format');
    }
  }

  static String _extractHeader(Uint8List data) {
    // Header is ASCII text up to "end_header\n"
    final int end = _findHeaderEnd(data);
    return utf8.decode(data.sublist(0, end));
  }

  static int _findHeaderEnd(Uint8List data) {
    final Uint8List marker = utf8.encode('end_header\n');
    final Uint8List markerR = utf8.encode('end_header\r\n');

    for (int i = 0; i < data.length - marker.length; i++) {
      bool matchR = true;
      if (i + markerR.length <= data.length) {
        matchR = true;
        for (int j = 0; j < markerR.length; j++) {
          if (data[i + j] != markerR[j]) {
            matchR = false;
            break;
          }
        }
        if (matchR) return i + markerR.length;
      }

      bool match = true;
      for (int j = 0; j < marker.length; j++) {
        if (data[i + j] != marker[j]) {
          match = false;
          break;
        }
      }
      if (match) return i + marker.length;
    }
    throw const FormatException('PLY header end_header not found');
  }

  static PlyModel _parseAscii(
    Uint8List data,
    int offset,
    int vertexCount,
    int faceCount,
    List<String> vertexProps,
  ) {
    final String body = utf8.decode(data.sublist(offset));
    final List<String> lines = const LineSplitter()
        .convert(body)
        .where((String l) => l.trim().isNotEmpty)
        .toList();

    final int xIdx = _propIndex(vertexProps, 'x');
    final int yIdx = _propIndex(vertexProps, 'y');
    final int zIdx = _propIndex(vertexProps, 'z');
    final int rIdx = _propIndexOpt(vertexProps, 'red');
    final int gIdx = _propIndexOpt(vertexProps, 'green');
    final int bIdx = _propIndexOpt(vertexProps, 'blue');

    final List<PlyVertex> vertices = <PlyVertex>[];
    for (int i = 0; i < vertexCount && i < lines.length; i++) {
      final List<String> parts = lines[i].trim().split(RegExp(r'\s+'));
      final double x = double.parse(parts[xIdx]);
      final double y = double.parse(parts[yIdx]);
      final double z = double.parse(parts[zIdx]);

      int r = 200, g = 200, b = 200;
      if (rIdx >= 0 && rIdx < parts.length) r = int.parse(parts[rIdx]);
      if (gIdx >= 0 && gIdx < parts.length) g = int.parse(parts[gIdx]);
      if (bIdx >= 0 && bIdx < parts.length) b = int.parse(parts[bIdx]);

      vertices.add(PlyVertex(x, y, z, Color.fromARGB(255, r, g, b)));
    }

    final List<PlyFace> faces = <PlyFace>[];
    for (
      int i = vertexCount;
      i < vertexCount + faceCount && i < lines.length;
      i++
    ) {
      final List<String> parts = lines[i].trim().split(RegExp(r'\s+'));
      final int n = int.parse(parts[0]);
      final List<int> indices = <int>[];
      for (int j = 1; j <= n && j < parts.length; j++) {
        indices.add(int.parse(parts[j]));
      }
      faces.add(PlyFace(indices));
    }

    return PlyModel(vertices: vertices, faces: faces);
  }

  static PlyModel _parseBinaryLE(
    Uint8List data,
    int offset,
    int vertexCount,
    int faceCount,
    List<String> vertexProps,
  ) {
    final ByteData bd = ByteData.sublistView(data);
    int pos = offset;

    // Determine vertex property layout (type + name)
    final List<_PropType> propTypes = <_PropType>[];
    for (final String line in vertexProps) {
      final List<String> parts = line.split(RegExp(r'\s+'));
      // "property <type> <name>"
      propTypes.add(_PropType(parts[1], parts[2]));
    }

    final int xIdx = propTypes.indexWhere((_PropType p) => p.name == 'x');
    final int yIdx = propTypes.indexWhere((_PropType p) => p.name == 'y');
    final int zIdx = propTypes.indexWhere((_PropType p) => p.name == 'z');
    final int rIdx = propTypes.indexWhere((_PropType p) => p.name == 'red');
    final int gIdx = propTypes.indexWhere((_PropType p) => p.name == 'green');
    final int bIdx = propTypes.indexWhere((_PropType p) => p.name == 'blue');

    final List<PlyVertex> vertices = <PlyVertex>[];
    for (int i = 0; i < vertexCount; i++) {
      final List<double> vals = <double>[];
      final List<int> ivals = <int>[];
      for (final _PropType pt in propTypes) {
        switch (pt.type) {
          case 'float':
          case 'float32':
            vals.add(bd.getFloat32(pos, Endian.little));
            ivals.add(bd.getFloat32(pos, Endian.little).round());
            pos += 4;
          case 'double':
          case 'float64':
            vals.add(bd.getFloat64(pos, Endian.little));
            ivals.add(bd.getFloat64(pos, Endian.little).round());
            pos += 8;
          case 'uchar':
          case 'uint8':
            vals.add(bd.getUint8(pos).toDouble());
            ivals.add(bd.getUint8(pos));
            pos += 1;
          case 'short':
          case 'int16':
            vals.add(bd.getInt16(pos, Endian.little).toDouble());
            ivals.add(bd.getInt16(pos, Endian.little));
            pos += 2;
          case 'ushort':
          case 'uint16':
            vals.add(bd.getUint16(pos, Endian.little).toDouble());
            ivals.add(bd.getUint16(pos, Endian.little));
            pos += 2;
          case 'int':
          case 'int32':
            vals.add(bd.getInt32(pos, Endian.little).toDouble());
            ivals.add(bd.getInt32(pos, Endian.little));
            pos += 4;
          case 'uint':
          case 'uint32':
            vals.add(bd.getUint32(pos, Endian.little).toDouble());
            ivals.add(bd.getUint32(pos, Endian.little));
            pos += 4;
          default:
            throw FormatException(
              'Unsupported vertex property type: ${pt.type}',
            );
        }
      }

      final double x = vals[xIdx];
      final double y = vals[yIdx];
      final double z = vals[zIdx];
      int r = 200, g = 200, b = 200;
      if (rIdx >= 0) r = ivals[rIdx].clamp(0, 255);
      if (gIdx >= 0) g = ivals[gIdx].clamp(0, 255);
      if (bIdx >= 0) b = ivals[bIdx].clamp(0, 255);

      vertices.add(PlyVertex(x, y, z, Color.fromARGB(255, r, g, b)));
    }

    // Parse faces
    final List<PlyFace> faces = <PlyFace>[];
    for (int i = 0; i < faceCount; i++) {
      final int n = bd.getUint8(pos);
      pos += 1;
      final List<int> indices = <int>[];
      for (int j = 0; j < n; j++) {
        indices.add(bd.getInt32(pos, Endian.little));
        pos += 4;
      }
      faces.add(PlyFace(indices));
    }

    return PlyModel(vertices: vertices, faces: faces);
  }

  static int _propIndex(List<String> props, String name) {
    for (int i = 0; i < props.length; i++) {
      if (props[i].split(RegExp(r'\s+')).last == name) return i;
    }
    throw FormatException('Required PLY property "$name" not found');
  }

  static int _propIndexOpt(List<String> props, String name) {
    for (int i = 0; i < props.length; i++) {
      if (props[i].split(RegExp(r'\s+')).last == name) return i;
    }
    return -1;
  }

  /// Compute the bounding-box center and max extent for normalisation.
  ({double cx, double cy, double cz, double extent}) get bounds {
    if (vertices.isEmpty) {
      return (cx: 0, cy: 0, cz: 0, extent: 1);
    }
    double minX = double.infinity,
        minY = double.infinity,
        minZ = double.infinity;
    double maxX = -double.infinity,
        maxY = -double.infinity,
        maxZ = -double.infinity;
    for (final PlyVertex v in vertices) {
      if (v.x < minX) minX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.z < minZ) minZ = v.z;
      if (v.x > maxX) maxX = v.x;
      if (v.y > maxY) maxY = v.y;
      if (v.z > maxZ) maxZ = v.z;
    }
    final double ex = max(max(maxX - minX, maxY - minY), maxZ - minZ);
    return (
      cx: (minX + maxX) / 2,
      cy: (minY + maxY) / 2,
      cz: (minZ + maxZ) / 2,
      extent: ex == 0 ? 1 : ex,
    );
  }
}

class _PropType {
  final String type;
  final String name;
  const _PropType(this.type, this.name);
}
