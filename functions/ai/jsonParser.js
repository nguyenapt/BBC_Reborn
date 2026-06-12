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
function parseJsonWithHint(response, openChar, closeChar) {
  const markdownPattern = openChar === "{" ?
    /```(?:json)?\s*(\{[\s\S]*?\})\s*```/ :
    /```(?:json)?\s*(\[[\s\S]*?\])\s*```/;
  const markdownMatch = response.match(markdownPattern);
  if (markdownMatch) {
    try {
      return JSON.parse(markdownMatch[1].trim());
    } catch (err) {
      throw new Error(
          `JSON parse failed (markdown): ${err instanceof Error ? err.message : err}. ` +
          `Snippet: ${response.slice(0, 300)}`,
      );
    }
  }

  const balanced = extractBalancedJson(response, openChar, closeChar);
  if (balanced) {
    try {
      return JSON.parse(balanced);
    } catch (err) {
      throw new Error(
          `JSON parse failed (balanced): ${err instanceof Error ? err.message : err}. ` +
          `Snippet: ${balanced.slice(0, 300)}`,
      );
    }
  }

  try {
    return JSON.parse(response.trim());
  } catch (err) {
    throw new Error(
        `JSON parse failed: ${err instanceof Error ? err.message : err}. ` +
        `Snippet: ${response.slice(0, 300)}`,
    );
  }
}

function parseJsonObject(response) {
  return parseJsonWithHint(response, "{", "}");
}

/**
 * @param {string} response
 * @returns {Array<Record<string, unknown>>}
 */
function parseJsonArray(response) {
  return parseJsonWithHint(response, "[", "]");
}

module.exports = {parseJsonObject, parseJsonArray};
