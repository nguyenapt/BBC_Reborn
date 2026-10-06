/// Wave-1 deepen features on a transcript line.
/// MUST_SYNC featureKey path segment with playMP3 DeepenCacheConstants / Cloud Functions actions.
enum DeepenFeature {
  paraphrase,
  chunks,
  simplify,
  nuance,
}

extension DeepenFeatureX on DeepenFeature {
  /// RTDB path segment under `deepen_by_episode/.../line_n/{featureKey}/{lang}`.
  String get featureKey {
    switch (this) {
      case DeepenFeature.paraphrase:
        return 'paraphrase';
      case DeepenFeature.chunks:
        return 'chunks';
      case DeepenFeature.simplify:
        return 'simplify';
      case DeepenFeature.nuance:
        return 'nuance';
    }
  }

  /// Cloud Functions `aiRequest` action name.
  String get cloudAction {
    switch (this) {
      case DeepenFeature.paraphrase:
        return 'paraphraseLine';
      case DeepenFeature.chunks:
        return 'extractLineChunks';
      case DeepenFeature.simplify:
        return 'simplifyLine';
      case DeepenFeature.nuance:
        return 'explainLineNuance';
    }
  }

  static DeepenFeature? fromFeatureKey(String? key) {
    switch (key) {
      case 'paraphrase':
        return DeepenFeature.paraphrase;
      case 'chunks':
        return DeepenFeature.chunks;
      case 'simplify':
        return DeepenFeature.simplify;
      case 'nuance':
        return DeepenFeature.nuance;
      default:
        return null;
    }
  }
}

/// Schema version embedded in deepen `data` payloads.
const String deepenSchemaVersion = 'deepen_v1';
