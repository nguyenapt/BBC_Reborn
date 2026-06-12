/**
 * Gemini REST provider
 */

/**
 * @param {string} apiKey
 * @param {string} model
 * @param {string} prompt
 * @param {string|undefined} systemPrompt
 * @returns {Promise<string>}
 */
async function callGemini(apiKey, model, prompt, systemPrompt) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
    `:generateContent?key=${encodeURIComponent(apiKey)}`;

  /** @type {Record<string, unknown>} */
  const requestBody = {
    contents: [{parts: [{text: prompt}]}],
    generationConfig: {temperature: 0.7, maxOutputTokens: 8192},
  };
  if (systemPrompt) {
    requestBody.systemInstruction = {parts: [{text: systemPrompt}]};
  }

  const response = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(requestBody),
  });

  const bodyText = await response.text();
  let data;
  try {
    data = JSON.parse(bodyText);
  } catch {
    throw new Error(`Gemini invalid JSON response: ${bodyText.slice(0, 200)}`);
  }

  if (!response.ok) {
    const msg = data?.error?.message ?? bodyText;
    if (response.status === 429 || String(msg).toLowerCase().includes("quota")) {
      const err = new Error(`Gemini rate limit: ${msg}`);
      err.code = "RATE_LIMIT";
      throw err;
    }
    throw new Error(`Gemini API error ${response.status}: ${msg}`);
  }

  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text || !String(text).trim()) {
    throw new Error("Empty response from Gemini");
  }
  return String(text);
}

module.exports = {callGemini};
