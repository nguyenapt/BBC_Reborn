/// Legacy slim `List/...` paths (HomePage / year trees) — disabled after CEFR cutover.
///
/// App reads full `/{A1…C2}.json` nodes. Re-enable only after a CEFR-aware List pipeline exists.
class RtdbListConfig {
  RtdbListConfig._();

  static const bool useSlimListPaths = bool.fromEnvironment(
    'RTDB_SLIM_LIST',
    defaultValue: false,
  );
}
