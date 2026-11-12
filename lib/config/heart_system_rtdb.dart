import 'firebase_rtdb_config.dart';

/// RTDB endpoint for client-readable heart economy config.
///
/// Upload [functions/app_client_config.seed.json] under `app_client_config`
/// in Firebase Console (same project as AppUpdate).
const String kHeartSystemRtdbUrl =
    '$kFirebaseRtdbBaseUrl/app_client_config/heart_system.json';
