abstract final class AppConstants {
  static const String dbName = 'rural_tourism_app.db';
  static const int dbVersion = 2;

  static const String destinationsAsset = 'assets/data/destinations.json';
  static const String accommodationsAsset = 'assets/data/accommodations.json';
  static const String similarPlacesAsset = 'assets/data/recommendations.json';

  static const int offlineRetrieveTopK = 20;

  static const double retrievalTextWeight = 0.70;
  static const double retrievalNumericWeight = 0.30;

  static const double finalTextScoreWeight = 0.40;
  static const double finalNumericScoreWeight = 0.20;
  static const double finalContextualScoreWeight = 0.40;

  static const double activityComponentWeight = 0.22;
  static const double vibeComponentWeight = 0.14;
  static const double seasonComponentWeight = 0.16;
  static const double budgetComponentWeight = 0.16;
  static const double accessibilityComponentWeight = 0.10;
  static const double familyComponentWeight = 0.08;
  static const double accommodationComponentWeight = 0.14;

  static const double maxAffinityBoost = 0.30;
  static const double affinityDecayFactor = 0.95;
  static const int coldStartThreshold = 5;

  static const double clickWeight = 1.0;
  static const double bookmarkWeight = 3.0;
  static const double dwellWeight = 2.0;
  static const int dwellThresholdSeconds = 10;

  static const int maxResultsPerDistrict = 2;
  static const int maxResultsPerCategory = 2;
}
