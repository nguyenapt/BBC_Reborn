import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/episode.dart';
import '../models/speaking_attempt.dart';
import '../models/speaking_feedback.dart';
import '../models/speaking_session.dart';
import '../services/language_manager.dart';
import '../services/local_database_service.dart';
import 'speaking_ai_analysis_screen.dart';

/// Danh sách attempt trong một session — mở lại [SpeakingAiAnalysisScreen].
class SpeakingSessionAttemptsScreen extends StatelessWidget {
  final SpeakingSession session;

  const SpeakingSessionAttemptsScreen({super.key, required this.session});

  Future<({List<SpeakingAttempt> attempts, Episode? episode})> _load(
    LocalDatabaseService db,
  ) async {
    final attempts = await db.getSpeakingAttempts(session.id);
    final ep = await db.getEpisodeById(session.episodeId);
    return (attempts: attempts, episode: ep);
  }

  Future<void> _openAttempt(
    BuildContext context,
    SpeakingAttempt attempt,
    Episode? episode,
  ) async {
    final db = LocalDatabaseService();
    Episode ep = episode ??
        (await db.getEpisodeById(attempt.episodeId)) ??
        Episode(
          actor: '',
          category: '',
          duration: '0:00',
          publishedDate: DateTime.now(),
          episodeName: session.episodeTitle.isNotEmpty
              ? session.episodeTitle
              : 'Episode',
          transcript: '',
          thumbImage: '',
          id: attempt.episodeId,
        );

    SpeakingFeedback feedback;
    if (attempt.feedbackJson != null && attempt.feedbackJson!.trim().isNotEmpty) {
      try {
        feedback = SpeakingFeedback.fromMap(
          jsonDecode(attempt.feedbackJson!) as Map<String, dynamic>,
        );
      } catch (_) {
        feedback = SpeakingFeedback(
          overallScore: attempt.score,
          pronunciationScore: attempt.score,
          fluencyScore: attempt.score,
          accuracyScore: attempt.score,
          feedback: attempt.feedback,
          mistakes: const [],
        );
      }
    } else {
      feedback = SpeakingFeedback(
        overallScore: attempt.score,
        pronunciationScore: attempt.score,
        fluencyScore: attempt.score,
        accuracyScore: attempt.score,
        feedback: attempt.feedback,
        mistakes: const [],
      );
    }

    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => SpeakingAiAnalysisScreen(
          episode: ep,
          feedback: feedback,
          recognizedText: attempt.recognizedText,
          referenceLineText: attempt.lineText,
          lineStartMs: attempt.lineStartMs,
          lineEndMs: attempt.lineEndMs,
          userRecordingPath: attempt.userRecordingPath,
          enableExitInterstitial: false,
        ),
      ),
    );
  }

  String _formatDate(LanguageManager lm, DateTime utc) {
    final loc = lm.currentLocale.toString();
    try {
      return DateFormat.yMMMd(loc).add_Hm().format(utc.toLocal());
    } catch (_) {
      return DateFormat.yMMMd().add_Hm().format(utc.toLocal());
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabaseService();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListenableBuilder(
      listenable: LanguageManager(),
      builder: (context, _) {
        final lm = LanguageManager();
        return Scaffold(
          appBar: AppBar(
            title: Text(lm.getText('speakingSessionAttemptsTitle')),
          ),
          body: FutureBuilder<({List<SpeakingAttempt> attempts, Episode? episode})>(
            future: _load(db),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              final attempts = data.attempts;
              if (attempts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      lm.getText('speakingLineHistoryEmpty'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                itemCount: attempts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final a = attempts[i];
                  return Material(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      title: Text(
                        lm.getTextWithParams('speakingHistoryAttemptScore', {
                          'score': a.score.toStringAsFixed(0),
                        }),
                      ),
                      subtitle: Text(
                        a.feedback.length > 120
                            ? '${a.feedback.substring(0, 117)}…'
                            : a.feedback,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        _formatDate(lm, a.createdAt),
                        style: theme.textTheme.labelSmall,
                      ),
                      onTap: () => _openAttempt(context, a, data.episode),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
