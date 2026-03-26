class ArtifactMetadata {
  final String projectId;
  final String siteId;
  final String locationId;
  final DateTime coverageDate;
  final String investigationTypes;
  final String materialTypes;
  final String culturalTerms;
  final String keywords;

  ArtifactMetadata({
    required this.projectId,
    required this.siteId,
    required this.locationId,
    required this.coverageDate,
    required this.investigationTypes,
    required this.materialTypes,
    required this.culturalTerms,
    required this.keywords,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ProjectID': projectId,
      'SiteID': siteId,
      'LocationID': locationId,
      'CoverageDate': coverageDate.toIso8601String(),
      'InvestigationTypes': investigationTypes,
      'MaterialTypes': materialTypes,
      'CulturalTerms': culturalTerms,
      'Keywords': keywords,
    };
  }
}
