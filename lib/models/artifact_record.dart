class ArtifactRecord {
  final String artifactId;
  final String projectId;
  final String siteId;
  final String locationId;
  final String? coverageDate;
  final String? modelStatus;
  final String? modelFilePath;
  final String? logFilePath;
  final bool? match;
  final String? matchDetail;

  ArtifactRecord({
    required this.artifactId,
    required this.projectId,
    required this.siteId,
    required this.locationId,
    this.coverageDate,
    this.modelStatus,
    this.modelFilePath,
    this.logFilePath,
    this.match,
    this.matchDetail,
  });

  factory ArtifactRecord.fromJson(Map<String, dynamic> json) {
    return ArtifactRecord(
      artifactId: json['ArtifactID']?.toString() ?? '',
      projectId: json['ProjectID']?.toString() ?? '',
      siteId: json['SiteID']?.toString() ?? '',
      locationId: json['LocationID']?.toString() ?? '',
      coverageDate: json['CoverageDate']?.toString(),
      modelStatus: json['3dModelCreatedStatus']?.toString(),
      modelFilePath: json['3dModelFilePath']?.toString(),
      logFilePath: json['LogFilePath']?.toString(),
      match: json['match'] is bool
          ? json['match'] as bool
          : (json['match']?.toString().toLowerCase() == 'true'),
      matchDetail: json['matchDetail']?.toString(),
    );
  }
}
