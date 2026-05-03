import 'package:flutter/material.dart';

import '../models/episode.dart';
import '../screens/episode_detail_screen.dart';
import 'admob_service.dart';

class EpisodeDetailOpenHelper {
  static bool _isOpeningEpisodeDetail = false;

  static Future<void> open({
    required BuildContext context,
    required Episode episode,
    required List<Episode> categoryEpisodes,
    bool replace = false,
  }) async {
    if (_isOpeningEpisodeDetail) return;
    _isOpeningEpisodeDetail = true;

    final navigator = Navigator.of(context);
    final route = MaterialPageRoute(
      builder: (ctx) => EpisodeDetailScreen(
        episode: episode,
        categoryEpisodes: categoryEpisodes,
      ),
    );

    final admob = AdMobService();
    admob.createInterstitialAd();
    await admob.ensureInterstitialLoaded();
    if (!context.mounted) {
      _isOpeningEpisodeDetail = false;
      return;
    }

    admob.showInterstitialAd(
      context: context,
      onDismissedOrUnavailable: () {
        if (!context.mounted) {
          _isOpeningEpisodeDetail = false;
          return;
        }

        final navFuture = replace
            ? navigator.pushReplacement(route)
            : navigator.push(route);
        navFuture.whenComplete(() {
          _isOpeningEpisodeDetail = false;
        });
      },
    );
  }
}
