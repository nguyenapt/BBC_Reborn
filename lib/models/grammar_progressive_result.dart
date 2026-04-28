import 'grammar_explanation.dart';

class GrammarPassageProgressiveResult {
  final GrammarExplanation initial;
  final Future<GrammarExplanation> full;

  GrammarPassageProgressiveResult({
    required this.initial,
    required this.full,
  });
}

