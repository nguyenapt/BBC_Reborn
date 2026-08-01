import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/speaking_session.dart';
import '../models/speaking_stats.dart';
import '../services/language_manager.dart';
import '../services/local_database_service.dart';
import 'speaking_session_attempts_screen.dart';
import '../widgets/episode_detail_tab_panel.dart';

class SpeakingHistoryScreen extends StatefulWidget {
  const SpeakingHistoryScreen({super.key});

  @override
  State<SpeakingHistoryScreen> createState() => _SpeakingHistoryScreenState();
}

class _SpeakingHistoryScreenState extends State<SpeakingHistoryScreen> {
  final LocalDatabaseService _db = LocalDatabaseService();

  Future<SpeakingStats> _loadStats() => _db.getSpeakingStats();

  Future<({List<SpeakingSession> sessions, Map<String, String> episodeNames})>
      _loadSessionsWithNames() async {
    final sessions = await _db.getSpeakingSessions(limit: 50);
    final names = await _db.getEpisodeDisplayNamesByIds(
      sessions.map((s) => s.episodeId).toSet(),
    );
    return (sessions: sessions, episodeNames: names);
  }

  String _episodeTitle(SpeakingSession session, Map<String, String> names) {
    if (session.episodeTitle.isNotEmpty) return session.episodeTitle;
    final n = names[session.episodeId];
    if (n != null && n.isNotEmpty) return n;
    return '—';
  }

  String _modeLabel(SpeakingSession session, LanguageManager lm) {
    switch (session.mode) {
      case 'roleplay':
        return lm.getText('speakingTabRoleplay');
      case 'repeat':
      default:
        return lm.getText('speakingTabRepeat');
    }
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final heading = Color.lerp(cs.primary, const Color(0xFF0B3D3D), 0.35)!;
    final softBg =
        Color.lerp(cs.surface, cs.primaryContainer, 0.2) ?? cs.surface;

    return ListenableBuilder(
      listenable: LanguageManager(),
      builder: (context, _) {
        final lm = LanguageManager();

        return Scaffold(
          backgroundColor: softBg,
          appBar: AppBar(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            elevation: 0,
            title: Text(lm.getText('speakingHistoryTitle')),
          ),
          body: Column(
            children: [
              FutureBuilder<SpeakingStats>(
                future: _loadStats(),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? SpeakingStats.empty();
                  return EpisodeDetailTabPanel.insetPanel(
                    context: context,
                    backgroundColor: cs.surface,
                    elevated: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          lm.getText('speakingHistoryTitle'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: heading,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _statLine(
                          theme,
                          heading,
                          lm.getTextWithParams('speakingHistoryStatAttempts', {
                            'count': '${stats.totalAttempts}',
                          }),
                        ),
                        _statLine(
                          theme,
                          heading,
                          lm.getTextWithParams('speakingHistoryStatAverage', {
                            'score': stats.averageScore.toStringAsFixed(1),
                          }),
                        ),
                        _statLine(
                          theme,
                          heading,
                          lm.getTextWithParams('speakingHistoryStatSessions', {
                            'count': '${stats.totalSessions}',
                          }),
                        ),
                        if (stats.lastPracticedAt != null) ...[
                          const SizedBox(height: 4),
                          _statLine(
                            theme,
                            heading.withValues(alpha: 0.85),
                            lm.getTextWithParams('speakingHistoryLastPracticed', {
                              'date': _formatDate(lm, stats.lastPracticedAt!),
                            }),
                            small: true,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: FutureBuilder<
                    ({
                      List<SpeakingSession> sessions,
                      Map<String, String> episodeNames
                    })>(
                  future: _loadSessionsWithNames(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: cs.primary,
                        ),
                      );
                    }
                    final data = snapshot.data;
                    final sessions = data?.sessions ?? [];
                    final episodeNames = data?.episodeNames ?? {};
                    if (sessions.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            lm.getText('speakingHistoryEmpty'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: heading.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        6,
                        0,
                        6,
                        24 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final mode = _modeLabel(session, lm);
                        final subtitle = lm.getTextWithParams(
                          'speakingHistorySessionSubtitle',
                          {
                            'attempts': '${session.totalAttempts}',
                            'avg': session.averageScore.toStringAsFixed(1),
                          },
                        );
                        return Material(
                          color: cs.surface,
                          elevation: 0,
                          borderRadius: BorderRadius.circular(
                            EpisodeDetailTabPanel.panelBorderRadius,
                          ),
                          shadowColor: Colors.black26,
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                EpisodeDetailTabPanel.panelBorderRadius,
                              ),
                              side: BorderSide(
                                color: cs.primary.withValues(alpha: 0.12),
                              ),
                            ),
                            title: Text(
                              _episodeTitle(session, episodeNames),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: heading,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${lm.getText('speakingHistoryModeLabel')}: $mode',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: heading.withValues(alpha: 0.65),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Text(
                              _formatDate(lm, session.updatedAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: heading.withValues(alpha: 0.5),
                              ),
                              textAlign: TextAlign.end,
                            ),
                            isThreeLine: true,
                            onTap: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (ctx) => SpeakingSessionAttemptsScreen(
                                    session: session,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statLine(
    ThemeData theme,
    Color color,
    String text, {
    bool small = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: small
            ? theme.textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.75),
              )
            : theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
      ),
    );
  }
}
