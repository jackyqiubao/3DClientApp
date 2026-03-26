import 'package:flutter/material.dart';

import '../models/artifact_metadata.dart';
import '../services/api_service.dart';
import 'photo_upload_screen.dart';

class MetadataFormScreen extends StatefulWidget {
  const MetadataFormScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<MetadataFormScreen> createState() => _MetadataFormScreenState();
}

class _MetadataFormScreenState extends State<MetadataFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _siteController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _investigationController =
      TextEditingController();
  final TextEditingController _materialController = TextEditingController();
  final TextEditingController _culturalController = TextEditingController();
  final TextEditingController _keywordsController = TextEditingController();

  DateTime? _coverageDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _projectController.dispose();
    _siteController.dispose();
    _locationController.dispose();
    _investigationController.dispose();
    _materialController.dispose();
    _culturalController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverageDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _coverageDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _coverageDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select a date'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final ArtifactMetadata metadata = ArtifactMetadata(
        projectId: _projectController.text.trim(),
        siteId: _siteController.text.trim(),
        locationId: _locationController.text.trim(),
        coverageDate: _coverageDate!,
        investigationTypes: _investigationController.text.trim(),
        materialTypes: _materialController.text.trim(),
        culturalTerms: _culturalController.text.trim(),
        keywords: _keywordsController.text.trim(),
      );

      final String uid = await widget.apiService.addArtifact(metadata);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server created ArtifactID: $uid')),
      );
      Navigator.of(context).push(
        MaterialPageRoute<Widget>(
          builder: (BuildContext context) =>
              PhotoUploadScreen(apiService: widget.apiService, uid: uid),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (String? value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String dateText = _coverageDate == null
        ? 'Select Coverage Date'
        : _coverageDate!.toLocal().toString().split(' ').first;

    return Scaffold(
      appBar: AppBar(title: const Text('Artifact Metadata')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              _buildTextField('ProjectID', _projectController),
              _buildTextField('SiteID', _siteController),
              _buildTextField('LocationID', _locationController),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _pickCoverageDate,
                icon: const Icon(Icons.date_range),
                label: Text(dateText),
              ),
              const SizedBox(height: 12),
              _buildTextField('InvestigationTypes', _investigationController),
              _buildTextField('MaterialTypes', _materialController),
              _buildTextField('CulturalTerms', _culturalController),
              _buildTextField('Keywords', _keywordsController),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
