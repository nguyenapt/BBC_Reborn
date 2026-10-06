/// Shared deepen prompts for local Gemini/OpenAI providers.
/// Keep aligned with functions/ai/prompts.js deepen builders.
class DeepenPromptBuilder {
  static String _contextPart(String? context) {
    final trimmed = context?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    return '\n\nSurrounding context (for accuracy only; focus on the line):\n$trimmed';
  }

  static String build(String action, String text, String targetLanguage,
      {String? context}) {
    final ctx = _contextPart(context);
    switch (action) {
      case 'paraphraseLine':
        return '''
You help English learners expand how to say the same idea.
Return ONLY a valid JSON object. No markdown.

Line: "$text"
Explain labels/notes in: $targetLanguage$ctx

Return format:
{
  "schemaVersion": "deepen_v1",
  "featureKey": "paraphrase",
  "alternatives": [
    {
      "text": "English paraphrase keeping the same meaning",
      "register": "formal|casual|neutral",
      "note": "short note in $targetLanguage"
    }
  ]
}

Rules:
- Provide 3 to 5 alternatives.
- Each alternative MUST be natural English, same core meaning as the line.
- Return ONLY the JSON object.''';
      case 'extractLineChunks':
        return '''
Extract useful multi-word chunks (collocations, idioms, fixed phrases) from this English line.
Do NOT paraphrase the whole sentence. Do NOT list single words unless part of a chunk.
Return ONLY a valid JSON object. No markdown.

Line: "$text"
Meanings/examples explanations in: $targetLanguage$ctx

Return format:
{
  "schemaVersion": "deepen_v1",
  "featureKey": "chunks",
  "chunks": [
    {
      "phrase": "exact multi-word chunk from the line when possible",
      "meaning": "short meaning in $targetLanguage",
      "example": "a NEW short English example sentence using the chunk"
    }
  ]
}

Rules:
- Provide 3 to 6 chunks.
- Prefer 2-5 word chunks learners should reuse as a unit.
- "example" must not merely copy the original line.
- Return ONLY the JSON object.''';
      case 'simplifyLine':
        return '''
Simplify this English line for learners who find it hard.
Return ONLY a valid JSON object. No markdown.

Line: "$text"
Hard-word meanings in: $targetLanguage$ctx

Return format:
{
  "schemaVersion": "deepen_v1",
  "featureKey": "simplify",
  "simplified": ["easier English sentence 1", "optional second simpler version"],
  "hardWords": [
    {"word": "difficult word or short phrase", "meaning": "short gloss in $targetLanguage"}
  ]
}

Rules:
- Provide 1 or 2 simplified English sentences that keep the same meaning.
- List up to 6 hard words/phrases from the original line.
- Return ONLY the JSON object.''';
      case 'explainLineNuance':
        return '''
Explain register and nuance of this English line (BBC-style news/learning English).
Return ONLY a valid JSON object. No markdown.

Line: "$text"
Write explanations in: $targetLanguage$ctx

Return format:
{
  "schemaVersion": "deepen_v1",
  "featureKey": "nuance",
  "register": "formal|informal|neutral",
  "implication": "what the speaker implies, in $targetLanguage",
  "britishNote": "British/BBC usage note in $targetLanguage, or empty string if none",
  "whyThisPhrasing": "why this wording was chosen, in $targetLanguage"
}

Rules:
- Be concise and practical for learners.
- Return ONLY the JSON object.''';
      default:
        throw ArgumentError('Unknown deepen action: $action');
    }
  }
}
