import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ConsentService {
  static final ConsentService _instance = ConsentService._internal();
  factory ConsentService() => _instance;
  ConsentService._internal();

  bool _canRequestAds = false;
  ConsentStatus _consentStatus = ConsentStatus.unknown;
  PrivacyOptionsRequirementStatus _privacyOptionsRequirementStatus =
      PrivacyOptionsRequirementStatus.unknown;
  bool _consentFlowFinished = false;

  bool get canRequestAds => _canRequestAds;
  bool get consentFlowFinished => _consentFlowFinished;
  ConsentStatus get consentStatus => _consentStatus;
  PrivacyOptionsRequirementStatus get privacyOptionsRequirementStatus =>
      _privacyOptionsRequirementStatus;

  bool get shouldShowPrivacyOptionsEntryPoint =>
      _privacyOptionsRequirementStatus ==
      PrivacyOptionsRequirementStatus.required;

  Future<void> initializeConsentFlow() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      _canRequestAds = false;
      _consentFlowFinished = true;
      return;
    }

    final ConsentRequestParameters params =
        ConsentRequestParameters(consentDebugSettings: _buildDebugSettings());

    try {
      await _requestConsentInfoUpdate(params);
    } catch (e) {
      debugPrint('UMP requestConsentInfoUpdate error: $e');
    }

    try {
      await ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) {
        if (formError != null) {
          debugPrint(
              'UMP loadAndShowConsentFormIfRequired dismissed with error: ${formError.message}');
        }
      });
    } catch (e) {
      debugPrint('UMP loadAndShowConsentFormIfRequired exception: $e');
    }

    await refreshConsentState();
    _consentFlowFinished = true;
  }

  Future<void> refreshConsentState() async {
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      _consentStatus = await ConsentInformation.instance.getConsentStatus();
      _privacyOptionsRequirementStatus = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
    } catch (e) {
      debugPrint('UMP refreshConsentState error: $e');
    }
  }

  Future<String?> showPrivacyOptionsForm() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return 'Privacy options hien chi ho tro tren Android/iOS.';
    }

    String? errorMessage;
    await ConsentForm.showPrivacyOptionsForm((FormError? formError) {
      if (formError != null) {
        errorMessage = formError.message;
      }
    });

    await refreshConsentState();
    return errorMessage;
  }

  Future<void> resetForTesting() async {
    await ConsentInformation.instance.reset();
    _canRequestAds = false;
    _consentStatus = ConsentStatus.unknown;
    _privacyOptionsRequirementStatus = PrivacyOptionsRequirementStatus.unknown;
    _consentFlowFinished = false;
  }

  Future<void> _requestConsentInfoUpdate(
      ConsentRequestParameters parameters) async {
    final Completer<void> completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      parameters,
      () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      (FormError error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    await completer.future;
  }

  ConsentDebugSettings? _buildDebugSettings() {
    if (!kDebugMode) return null;

    final bool forceEea =
        const bool.fromEnvironment('UMP_DEBUG_EEA', defaultValue: false);
    final String testIdentifier =
        const String.fromEnvironment('UMP_TEST_DEVICE_ID', defaultValue: '');

    if (!forceEea && testIdentifier.isEmpty) {
      return null;
    }

    return ConsentDebugSettings(
      debugGeography:
          forceEea ? DebugGeography.debugGeographyEea : null,
      testIdentifiers: testIdentifier.isEmpty ? null : <String>[testIdentifier],
    );
  }
}
