import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/artifact_record.dart';
import '../services/api_service.dart';
import 'metadata_form_screen.dart';
import 'ply_viewer_screen.dart';

class QueryArtifactsScreen extends StatefulWidget {
  const QueryArtifactsScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<QueryArtifactsScreen> createState() => _QueryArtifactsScreenState();
}

class _QueryArtifactsScreenState extends State<QueryArtifactsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _artifactIdController = TextEditingController();
  final TextEditingController _projectIdController = TextEditingController();
  final TextEditingController _siteIdController = TextEditingController();
  final TextEditingController _locationIdController = TextEditingController();
  final TextEditingController _investigationTypesController =
      TextEditingController();
  final TextEditingController _materialTypesController =
      TextEditingController();
  final TextEditingController _culturalTermsController =
      TextEditingController();
  final TextEditingController _keywordsController = TextEditingController();

  DateTime? _coverageStart;
  DateTime? _coverageEnd;
  DateTime? _createdStart;
  DateTime? _createdEnd;

  final ImagePicker _picker = ImagePicker();
  XFile? _pictureToMatch;

  bool _isLoading = false;
  List<ArtifactRecord> _results = <ArtifactRecord>[];

  @override
  void dispose() {
    _artifactIdController.dispose();
    _projectIdController.dispose();
    _siteIdController.dispose();
    _locationIdController.dispose();
    _investigationTypesController.dispose();
    _materialTypesController.dispose();
    _culturalTermsController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange({
    required bool isCoverage,
    required bool isStart,
  }) async {
    final DateTime initial = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isCoverage) {
        if (isStart) {
          _coverageStart = picked;
        } else {
          _coverageEnd = picked;
        }
      } else {
        if (isStart) {
          _createdStart = picked;
        } else {
          _createdEnd = picked;
        }
      }
    });
  }

  String _formatDate(DateTime? value) =>
      value == null ? '' : value.toLocal().toString().split(' ').first;

  String _buildSqlWhere() {
    final List<String> conditions = <String>['1=1'];

    void addLike(String field, String value) {
      if (value.trim().isEmpty) return;
      final String escaped = value.replaceAll("'", "''");
      conditions.add("$field LIKE '%" + escaped.replaceAll('%', '\\%') + "%'");
    }

    addLike('ArtifactID', _artifactIdController.text);
    addLike('ProjectID', _projectIdController.text);
    addLike('SiteID', _siteIdController.text);
    addLike('LocationID', _locationIdController.text);
    addLike('InvestigationTypes', _investigationTypesController.text);
    addLike('MaterialTypes', _materialTypesController.text);
    addLike('CulturalTerms', _culturalTermsController.text);
    addLike('Keywords', _keywordsController.text);

    if (_coverageStart != null) {
      conditions.add("CoverageDate >= '${_coverageStart!.toIso8601String()}'");
    }
    if (_coverageEnd != null) {
      conditions.add("CoverageDate <= '${_coverageEnd!.toIso8601String()}'");
    }
    if (_createdStart != null) {
      conditions.add("CreatedTime >= '${_createdStart!.toIso8601String()}'");
    }
    if (_createdEnd != null) {
      conditions.add("CreatedTime <= '${_createdEnd!.toIso8601String()}'");
    }

    return conditions.join(' AND ');
  }

  Future<void> _pickPictureToMatch() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pictureToMatch = picked;
      });
    }
  }

  Future<void> _query() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final String sqlWhere = _buildSqlWhere();

    setState(() {
      _isLoading = true;
    });

    try {
      final List<ArtifactRecord> records = await widget.apiService
          .queryArtifacts(sqlWhere: sqlWhere, picture: _pictureToMatch);
      if (!mounted) return;
      setState(() {
        _results = records;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Query failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onMenuSelected(String value) {
    if (value == 'search') {
      // Already on search page.
      return;
    }
    if (value == 'scan') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<Widget>(
          builder: (BuildContext context) =>
              MetadataFormScreen(apiService: widget.apiService),
        ),
      );
    }
  }

  PopupMenuButton<String> _buildMainMenu() {
    return PopupMenuButton<String>(
      onSelected: _onMenuSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'search',
          child: Text('Search Artifacts'),
        ),
        const PopupMenuItem<String>(
          value: 'scan',
          child: Text('Scan New Artifact'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Artifacts'),
        actions: <Widget>[_buildMainMenu()],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextFormField(
                        controller: _artifactIdController,
                        decoration: const InputDecoration(
                          labelText: 'ArtifactID',
                        ),
                      ),
                      TextFormField(
                        controller: _projectIdController,
                        decoration: const InputDecoration(
                          labelText: 'ProjectID',
                        ),
                      ),
                      TextFormField(
                        controller: _siteIdController,
                        decoration: const InputDecoration(labelText: 'SiteID'),
                      ),
                      TextFormField(
                        controller: _locationIdController,
                        decoration: const InputDecoration(
                          labelText: 'LocationID',
                        ),
                      ),
                      TextFormField(
                        controller: _investigationTypesController,
                        decoration: const InputDecoration(
                          labelText: 'InvestigationTypes',
                        ),
                      ),
                      TextFormField(
                        controller: _materialTypesController,
                        decoration: const InputDecoration(
                          labelText: 'MaterialTypes',
                        ),
                      ),
                      TextFormField(
                        controller: _culturalTermsController,
                        decoration: const InputDecoration(
                          labelText: 'CulturalTerms',
                        ),
                      ),
                      TextFormField(
                        controller: _keywordsController,
                        decoration: const InputDecoration(
                          labelText: 'Keywords',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('CoverageDate Range'),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextButton(
                              onPressed: () => _pickDateRange(
                                isCoverage: true,
                                isStart: true,
                              ),
                              child: Text(
                                _coverageStart == null
                                    ? 'Start'
                                    : _formatDate(_coverageStart),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: () => _pickDateRange(
                                isCoverage: true,
                                isStart: false,
                              ),
                              child: Text(
                                _coverageEnd == null
                                    ? 'End'
                                    : _formatDate(_coverageEnd),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('CreatedTime Range'),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextButton(
                              onPressed: () => _pickDateRange(
                                isCoverage: false,
                                isStart: true,
                              ),
                              child: Text(
                                _createdStart == null
                                    ? 'Start'
                                    : _formatDate(_createdStart),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: () => _pickDateRange(
                                isCoverage: false,
                                isStart: false,
                              ),
                              child: Text(
                                _createdEnd == null
                                    ? 'End'
                                    : _formatDate(_createdEnd),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          ElevatedButton.icon(
                            onPressed: _pickPictureToMatch,
                            icon: const Icon(Icons.image_search),
                            label: const Text('PictureToMatch'),
                          ),
                          const SizedBox(width: 8),
                          if (_pictureToMatch != null)
                            Text(
                              _pictureToMatch!.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _query,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Search'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('No results'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (BuildContext context, int index) {
                      final ArtifactRecord r = _results[index];
                      final bool has3D =
                          r.modelStatus?.toLowerCase() == 'success' &&
                          r.modelFilePath != null &&
                          r.modelFilePath!.isNotEmpty;
                      return ListTile(
                        title: Text(
                          'ArtifactID: ${r.artifactId}  ProjectID: ${r.projectId}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Site: ${r.siteId}  Location: ${r.locationId}\n'
                              'Coverage: ${r.coverageDate ?? '-'}  Status: ${r.modelStatus ?? '-'}\n'
                              'Match: ${r.match == true ? 'YES' : 'NO'}',
                            ),
                            if (has3D)
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<Widget>(
                                      builder: (BuildContext context) =>
                                          PlyViewerScreen(
                                            apiService: widget.apiService,
                                            uid: r.artifactId,
                                          ),
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'View 3D Model',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          showDialog<void>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Artifact Details'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text('ArtifactID: ${r.artifactId}'),
                                      Text('ProjectID: ${r.projectId}'),
                                      Text('SiteID: ${r.siteId}'),
                                      Text('LocationID: ${r.locationId}'),
                                      const SizedBox(height: 8),
                                      Text(
                                        'CoverageDate: ${r.coverageDate ?? '-'}',
                                      ),
                                      Text(
                                        '3D Status: ${r.modelStatus ?? '-'}',
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '3D Model Path:\n${r.modelFilePath ?? '-'}',
                                      ),
                                      if (has3D)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.pop(context);
                                              Navigator.of(context).push(
                                                MaterialPageRoute<Widget>(
                                                  builder:
                                                      (BuildContext context) =>
                                                          PlyViewerScreen(
                                                            apiService: widget
                                                                .apiService,
                                                            uid: r.artifactId,
                                                          ),
                                                ),
                                              );
                                            },
                                            child: const Text(
                                              'View 3D Model',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Log File Path:\n${r.logFilePath ?? '-'}',
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Match: ${r.match == true ? 'YES' : 'NO'}',
                                      ),
                                      if (r.matchDetail != null &&
                                          r.matchDetail!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            'Detail: ${r.matchDetail}',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
