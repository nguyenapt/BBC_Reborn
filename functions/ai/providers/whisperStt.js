/**
 * OpenAI Whisper STT fallback (port of SpeechTranscriptionService whisper path)
 */

/**
 * @param {string} bcp47
 * @returns {string}
 */
function whisperLanguageCode(bcp47) {
  const parts = String(bcp47 || "en-US").split(/[-_]/);
  const code = (parts[0] || "en").toLowerCase();
  if (code.length === 2 || code.length === 3) return code;
  return "en";
}

/**
 * @param {string} apiKey
 * @param {Buffer} audioBytes
 * @param {string} language
 * @returns {Promise<string>}
 */
async function callWhisperStt(apiKey, audioBytes, language) {
  if (!apiKey) {
    throw new Error("OpenAI API key not configured for Whisper STT");
  }
  if (!audioBytes || audioBytes.length === 0) {
    throw new Error("Audio file is empty");
  }

  const lang = whisperLanguageCode(language);
  const form = new FormData();
  form.append("model", "whisper-1");
  form.append("language", lang);
  form.append(
      "file",
      new Blob([audioBytes], {type: "audio/wav"}),
      "speech.wav",
  );

  const response = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
    },
    body: form,
  });

  const bodyText = await response.text();
  if (response.ok) {
    let data;
    try {
      data = JSON.parse(bodyText);
    } catch {
      throw new Error(`Whisper invalid JSON: ${bodyText.slice(0, 200)}`);
    }
    const text = data?.text?.toString().trim() ?? "";
    if (!text) {
      throw new Error("Whisper returned empty text");
    }
    return text;
  }

  if (response.status === 429) {
    const err = new Error(`Whisper rate limit: ${bodyText}`);
    err.code = "RATE_LIMIT";
    throw err;
  }

  throw new Error(`Whisper API error ${response.status}: ${bodyText.slice(0, 300)}`);
}

module.exports = {callWhisperStt, whisperLanguageCode};
