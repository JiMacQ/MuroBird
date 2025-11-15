// lib/offline/offline_models.dart
class OfflineBirdDetails {
  final String displayTitle;
  final String scientificName;
  final String? descriptionEs;
  final String? descriptionEn;
  final String? coverImage;
  final List<String> gallery;
  final List<String> audios;
  final List<String> spectrograms;
  final String? distributionGeoJson;

  OfflineBirdDetails({
    required this.displayTitle,
    required this.scientificName,
    this.descriptionEs,
    this.descriptionEn,
    this.coverImage,
    this.gallery = const [],
    this.audios = const [],
    this.spectrograms = const [],
    this.distributionGeoJson,
  });

  factory OfflineBirdDetails.fromDb(Map<String, dynamic> m) {
    final a = Map<String, dynamic>.from(m['assets'] ?? {});
    return OfflineBirdDetails(
      displayTitle:
          (m['common_name_es'] ?? m['common_name_en'] ?? m['scientific_name'])
              as String,
      scientificName: m['scientific_name'] as String,
      descriptionEs: (m['description']?['es'] as String?)?.trim(),
      descriptionEn: (m['description']?['en'] as String?)?.trim(),
      coverImage: a['image_cover'] as String?,
      gallery: (a['gallery'] as List? ?? []).cast<String>(),
      audios: (a['audio_samples'] as List? ?? []).cast<String>(),
      spectrograms: (a['spectrograms'] as List? ?? []).cast<String>(),
      distributionGeoJson: a['distribution_geojson'] as String?,
    );
  }
}
