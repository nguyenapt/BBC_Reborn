/**
 * OpenAI chat completions provider
 */

/**
 * @param {string} apiKey
 * @param {string} model
 * @param {string} prompt
 * @param {string|undefined} systemPrompt
 * @returns {Promise<string>}
 */
async function callOpenAI(apiKey, model, prompt, systemPrompt) {
  /** @type {Array<{role: string, content: string}>} */
  const messages = [];
  if (systemPrompt) {
    messages.push({role: "system", content: systemPrompt});
  }
  messages.push({role: "user", content: prompt});

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages,
      temperature: 0.7,
    }),
  });

  const bodyText = await response.text();
  let data;
  try {
    data = JSON.parse(bodyText);
  } catch {
    throw new Error(`OpenAI invalid JSON response: ${bodyText.slice(0, 200)}`);
  }

  if (!response.ok) {
    const msg = data?.error?.message ?? bodyText;
    if (response.status === 429) {
      const err = new Error(`OpenAI rate limit: ${msg}`);
      err.code = "RATE_LIMIT";
      throw err;
    }
    throw new Error(`OpenAI API error ${response.status}: ${msg}`);
  }

  const content = data?.choices?.[0]?.message?.content;
  if (!content || !String(content).trim()) {
    throw new Error("Empty response from OpenAI");
  }
  return String(content);
}

module.exports = {callOpenAI};
