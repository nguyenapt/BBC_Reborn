import 'package:flutter/material.dart';
import '../models/deepen_feature.dart';
import '../services/language_manager.dart';

/// Bottom sheet listing Wave-1 deepen actions for one transcript line.
Future<DeepenFeature?> showTranscriptLineDeepenSheet(BuildContext context) {
  final lang = LanguageManager();
  return showModalBottomSheet<DeepenFeature>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final items = <({DeepenFeature feature, String titleKey, String descKey, IconData icon})>[
        (
          feature: DeepenFeature.paraphrase,
          titleKey: 'deepenParaphrase',
          descKey: 'deepenParaphraseDesc',
          icon: Icons.swap_horiz,
        ),
        (
          feature: DeepenFeature.chunks,
          titleKey: 'deepenChunks',
          descKey: 'deepenChunksDesc',
          icon: Icons.auto_awesome_motion,
        ),
        (
          feature: DeepenFeature.simplify,
          titleKey: 'deepenSimplify',
          descKey: 'deepenSimplifyDesc',
          icon: Icons.short_text,
        ),
        (
          feature: DeepenFeature.nuance,
          titleKey: 'deepenNuance',
          descKey: 'deepenNuanceDesc',
          icon: Icons.psychology_outlined,
        ),
      ];

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                lang.getText('deepenTitle'),
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            for (final item in items)
              ListTile(
                leading: Icon(item.icon),
                title: Text(lang.getText(item.titleKey)),
                subtitle: Text(lang.getText(item.descKey)),
                onTap: () => Navigator.of(ctx).pop(item.feature),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Result dialog for a deepen feature payload.
void showDeepenResultDialog({
  required BuildContext context,
  required DeepenFeature feature,
  required Map<String, dynamic> data,
  required String sourceSentence,
}) {
  final lang = LanguageManager();
  final title = switch (feature) {
    DeepenFeature.paraphrase => lang.getText('deepenParaphrase'),
    DeepenFeature.chunks => lang.getText('deepenChunks'),
    DeepenFeature.simplify => lang.getText('deepenSimplify'),
    DeepenFeature.nuance => lang.getText('deepenNuance'),
  };

  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sourceSentence,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                ..._buildFeatureBody(ctx, lang, feature, data),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(lang.getText('close')),
          ),
        ],
      );
    },
  );
}

List<Widget> _buildFeatureBody(
  BuildContext context,
  LanguageManager lang,
  DeepenFeature feature,
  Map<String, dynamic> data,
) {
  switch (feature) {
    case DeepenFeature.paraphrase:
      final alts = data['alternatives'];
      if (alts is! List || alts.isEmpty) {
        return [Text(lang.getText('deepenEmptyResult'))];
      }
      return [
        for (var i = 0; i < alts.length; i++) ...[
          if (alts[i] is Map) ...[
            Text(
              '${i + 1}. ${(alts[i] as Map)['text'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (((alts[i] as Map)['register']?.toString() ?? '').isNotEmpty)
              Text(
                '${lang.getText('deepenRegister')}: ${(alts[i] as Map)['register']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (((alts[i] as Map)['note']?.toString() ?? '').isNotEmpty)
              Text(
                '${lang.getText('deepenNote')}: ${(alts[i] as Map)['note']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 10),
          ],
        ],
      ];
    case DeepenFeature.chunks:
      final chunks = data['chunks'];
      if (chunks is! List || chunks.isEmpty) {
        return [Text(lang.getText('deepenEmptyResult'))];
      }
      return [
        for (final raw in chunks)
          if (raw is Map) ...[
            Text(
              raw['phrase']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if ((raw['meaning']?.toString() ?? '').isNotEmpty)
              Text('${lang.getText('deepenMeaning')}: ${raw['meaning']}'),
            if ((raw['example']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 10),
                child: Text(
                  '${lang.getText('deepenExample')}: ${raw['example']}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
          ],
      ];
    case DeepenFeature.simplify:
      final simplified = data['simplified'];
      final hardWords = data['hardWords'];
      return [
        Text(
          lang.getText('deepenSimplified'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        if (simplified is List)
          for (final s in simplified)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• ${s.toString()}'),
            ),
        if (hardWords is List && hardWords.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            lang.getText('deepenHardWords'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (final raw in hardWords)
            if (raw is Map)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${raw['word'] ?? ''}: ${raw['meaning'] ?? ''}',
                ),
              ),
        ],
      ];
    case DeepenFeature.nuance:
      return [
        _nuanceRow(lang.getText('deepenRegister'), data['register']),
        _nuanceRow(lang.getText('deepenImplication'), data['implication']),
        _nuanceRow(lang.getText('deepenBritishNote'), data['britishNote']),
        _nuanceRow(lang.getText('deepenWhyPhrasing'), data['whyThisPhrasing']),
      ];
  }
}

Widget _nuanceRow(String label, dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(text),
      ],
    ),
  );
}
