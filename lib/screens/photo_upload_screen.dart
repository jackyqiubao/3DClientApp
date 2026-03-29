import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import 'query_artifacts_screen.dart';

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({
    super.key,
    required this.apiService,
    required this.uid,
  });

  final ApiService apiService;
  final String uid;

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = <XFile>[];
  bool _isUploading = false;

  Future<void> _pickFromGallery() async {
    final List<XFile> picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked);
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _images.add(photo);
      });
    }
  }

  Future<void> _upload() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await widget.apiService.upload(widget.uid, _images);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload successful')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Photos (UID: ${widget.uid})'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'search') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<Widget>(
                    builder: (BuildContext context) =>
                        QueryArtifactsScreen(apiService: widget.apiService),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'search',
                child: Text('Search Artifacts'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _images.isEmpty
                ? const Center(child: Text('No images selected'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                    itemCount: _images.length,
                    itemBuilder: (BuildContext context, int index) {
                      if (kIsWeb) {
                        return Image.network(
                          _images[index].path,
                          fit: BoxFit.cover,
                        );
                      }

                      return Image.file(
                        File(_images[index].path),
                        fit: BoxFit.cover,
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _upload,
                    child: _isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Upload'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<Widget>(
                          builder: (BuildContext context) =>
                              QueryArtifactsScreen(
                                apiService: widget.apiService,
                              ),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    },
                    child: const Text('Return to Search Artifacts'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
