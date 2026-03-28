import 'package:flutter/material.dart';

import '../models/speaking_feedback.dart';

/// Tô nền các đoạn [SpeakingMistake.expected] xuất hiện trong [referenceText].
class SpeakingReferenceHighlight extends StatelessWidget {
  final String referenceText;
  final List<SpeakingMistake> mistakes;
  final TextStyle? style;
  final Color highlightColor;
  final Color textColor;

  const SpeakingReferenceHighlight({
    super.key,
    required this.referenceText,
    required this.mistakes,
    this.style,
    required this.highlightColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ??
        Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4) ??
        TextStyle(fontSize: 16, height: 1.4, color: textColor);

    final spans = _buildSpans(base);
    return Text.rich(TextSpan(children: spans));
  }

  List<InlineSpan> _buildSpans(TextStyle base) {
    if (referenceText.isEmpty) {
      return [TextSpan(text: '', style: base)];
    }

    final lower = referenceText.toLowerCase();
    final intervals = <({int start, int end})>[];

    for (final m in mistakes) {
      final exp = m.expected.trim();
      if (exp.isEmpty) continue;
      var from = 0;
      final el = exp.toLowerCase();
      while (true) {
        final i = lower.indexOf(el, from);
        if (i < 0) break;
        intervals.add((start: i, end: i + exp.length));
        from = i + 1;
      }
    }

    if (intervals.isEmpty) {
      return [
        TextSpan(text: referenceText, style: base.copyWith(color: textColor)),
      ];
    }

    intervals.sort((a, b) => a.start.compareTo(b.start));
    final merged = <({int start, int end})>[];
    for (final iv in intervals) {
      if (merged.isEmpty) {
        merged.add(iv);
        continue;
      }
      final last = merged.last;
      if (iv.start <= last.end) {
        merged[merged.length - 1] = (
          start: last.start,
          end: iv.end > last.end ? iv.end : last.end,
        );
      } else {
        merged.add(iv);
      }
    }

    final out = <InlineSpan>[];
    var cursor = 0;
    for (final iv in merged) {
      if (cursor < iv.start) {
        out.add(
          TextSpan(
            text: referenceText.substring(cursor, iv.start),
            style: base.copyWith(color: textColor),
          ),
        );
      }
      out.add(
        TextSpan(
          text: referenceText.substring(iv.start, iv.end),
          style: base.copyWith(
            color: textColor,
            backgroundColor: highlightColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      cursor = iv.end;
    }
    if (cursor < referenceText.length) {
      out.add(
        TextSpan(
          text: referenceText.substring(cursor),
          style: base.copyWith(color: textColor),
        ),
      );
    }
    return out;
  }
}
