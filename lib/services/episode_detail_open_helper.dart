import 'package:flutter/material.dart';

import '../models/episode.dart';
import '../screens/episode_detail_screen.dart';
import 'admob_service.dart';

class EpisodeDetailOpenHelper {
  static bool _isOpeningEpisodeDetail = false;

  static void open({
    required BuildContext context,
    required Episode episode,
    required List<Episode> categoryEpisodes,
    bool replace = false,
  }) {
    if (_isOpeningEpisodeDetail) return;
    _isOpeningEpisodeDetail = true;

    final navigator = Navigator.of(context);
    final route = MaterialPageRoute(
      builder: (ctx) => EpisodeDetailScreen(
        episode: episode,
        categoryEpisodes: categoryEpisodes,
      ),
    );

    AdMobService().createInterstitialAd();
    AdMobService().showInterstitialAd(
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
