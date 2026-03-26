import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/artifact_metadata.dart';

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
}
