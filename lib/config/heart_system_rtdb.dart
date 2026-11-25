import 'firebase_rtdb_config.dart';

/// RTDB endpoint for client-readable heart economy config.
///
/// Upload [functions/app_client_config.seed.json] under
/// `Configuration/app_client_config` in Firebase Console.
const String kHeartSystemRtdbUrl =
    '$kFirebaseRtdbBaseUrl/Configuration/app_client_config/heart_system.json';
