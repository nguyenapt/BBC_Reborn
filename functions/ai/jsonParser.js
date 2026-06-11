/**
 * Port of lib/services/ai/json_parser_helper.dart
 */

/**
 * @param {string} text
 * @param {string} openChar
 * @param {string} closeChar
 * @returns {string|null}
 */
function extractBalancedJson(text, openChar, closeChar) {
  const startIndex = text.indexOf(openChar);
  if (startIndex === -1) return null;

  let depth = 0;
  let endIndex = startIndex;

  for (let i = startIndex; i < text.length; i++) {
    if (text[i] === openChar) depth++;
    else if (text[i] === closeChar) {
      depth--;
      if (depth === 0) {
        endIndex = i + 1;
        break;
      }
    }
  }

  if (depth === 0 && endIndex > startIndex) {
    return text.substring(startIndex, endIndex);
  }
  return null;
}

/**
 * @param {string} response
 * @returns {Record<string, unknown>}
 */
function parseJsonObject(response) {
  const markdownMatch = response.match(/```(?:json)?\s*(\{[\s\S]*?\})\s*```/);
  if (markdownMatch) {
    return JSON.parse(markdownMatch[1].trim());
  }

  const balanced = extractBalancedJson(response, "{", "}");
  if (balanced) {
    return JSON.parse(balanced);
  }

  return JSON.parse(response.trim());
}

/**
 * @param {string} response
 * @returns {Array<Record<string, unknown>>}
 */
function parseJsonArray(response) {
  const markdownMatch = response.match(/```(?:json)?\s*(\[[\s\S]*?\])\s*```/);
  if (markdownMatch) {
    const parsed = JSON.parse(markdownMatch[1].trim());
    return parsed;
  }

  const balanced = extractBalancedJson(response, "[", "]");
  if (balanced) {
    return JSON.parse(balanced);
  }

  return JSON.parse(response.trim());
}

module.exports = {parseJsonObject, parseJsonArray};
