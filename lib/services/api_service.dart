import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/artifact_metadata.dart';
import '../models/artifact_record.dart';

class ApiService {
  final String baseUrl;

  ApiService(this.baseUrl);

  Future<String> addArtifact(ArtifactMetadata metadata) async {
    final Uri url = Uri.parse('$baseUrl/add_artifact');
    print('DEBUG: call addArtifact started');
    // Server expects JSON body (like Python requests.post(url, json=data)).
    final http.Response response = await http.post(
      url,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(metadata.toJson()),
    );

    print('DEBUG: received response body: ${response.body}');

    if (response.statusCode == 200) {
      final dynamic body = jsonDecode(response.body);

      if (body is Map<String, dynamic>) {
        // Flask returns {"ArtifactID": "..."} on success.
        if (body['ArtifactID'] != null) {
          return body['ArtifactID'].toString();
        }
        if (body['error'] != null) {
          throw Exception(body['error'].toString());
        }
      }

      throw Exception('Unexpected response: ${response.body}');
    } else {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }
  }

  Future<List<ArtifactRecord>> queryArtifacts({
    required String sqlWhere,
    XFile? picture,
  }) async {
    final Uri url = Uri.parse('$baseUrl/query_artifacts');

    http.Response response;
    print(
      'DEBUG: call queryArtifacts with sqlWhere="$sqlWhere" and picture=${picture?.name}',
    );
    if (picture == null) {
      response = await http.post(
        url,
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{'sqlwhere': sqlWhere}),
      );
    } else {
      final http.MultipartRequest request = http.MultipartRequest('POST', url)
        ..fields['sqlwhere'] = sqlWhere;

      if (kIsWeb) {
        final List<int> bytes = await picture.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('image', bytes, filename: picture.name),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('image', picture.path),
        );
      }

      final http.StreamedResponse streamed = await request.send();
      response = await http.Response.fromStream(streamed);
    }

    if (response.statusCode != 200) {
      throw Exception(
        'query_artifacts failed: ${response.statusCode} ${response.body}',
      );
    }

    final dynamic body = jsonDecode(response.body);

    // Expecting: { "artifacts": [ {...}, {...} ] }
    if (body is Map<String, dynamic> && body['artifacts'] is List) {
      final List<dynamic> list = body['artifacts'] as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map<ArtifactRecord>(ArtifactRecord.fromJson)
          .toList();
    }

    throw Exception('Unexpected query_artifacts response: ${response.body}');
  }

  /// Uploads all images for a given folder (ArtifactID) and
  /// triggers 3D reconstruction on the last image (completed=true).
  Future<void> upload(String folderName, List<XFile> images) async {
    if (images.isEmpty) {
      return;
    }

    for (int i = 0; i < images.length; i++) {
      final bool isLast = i == images.length - 1;
      await _uploadSingleImage(
        folderName: folderName,
        image: images[i],
        completed: isLast,
      );
    }
  }

  Future<void> _uploadSingleImage({
    required String folderName,
    required XFile image,
    required bool completed,
  }) async {
    final Uri url = Uri.parse('$baseUrl/upload');

    final http.MultipartRequest request = http.MultipartRequest('POST', url)
      ..fields['folder_name'] = folderName
      ..fields['completed'] = completed ? 'true' : 'false';

    if (kIsWeb) {
      // On web, use bytes because dart:io File is not available.
      final List<int> bytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: image.name),
      );
    } else {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    final http.StreamedResponse streamedResponse = await request.send();
    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} ${response.body}');
    }
  }

  /// Downloads a 3D model file (PLY) from the server.
  /// [uid] is the ArtifactID whose model should be downloaded.
  Future<Uint8List> downloadModel(String uid) async {
    final Uri url = Uri.parse(
      '$baseUrl/download_model',
    ).replace(queryParameters: <String, String>{'uid': uid});

    final http.Response response = await http.get(url);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception(
      'Failed to download model: ${response.statusCode} ${response.body}',
    );
  }
}
