/**
 * Azure Speech-to-Text REST provider (port of lib/services/azure_stt_service.dart)
 */

/**
 * @param {Buffer} audioBytes
 * @returns {number}
 */
function readPcmWavSampleRate(audioBytes) {
  if (audioBytes.length < 36) return 0;
  if (audioBytes[0] !== 0x52 || audioBytes[1] !== 0x49 ||
      audioBytes[2] !== 0x46 || audioBytes[3] !== 0x46) {
    return 0;
  }
  let i = 12;
  while (i + 8 < audioBytes.length) {
    const chunkId = audioBytes.toString("ascii", i, i + 4);
    const chunkSize = audioBytes.readInt32LE(i + 4);
    if (chunkId === "fmt ") {
      if (i + 16 > audioBytes.length) return 0;
      const audioFormat = audioBytes.readUInt16LE(i + 8);
      if (audioFormat !== 1) return 0;
      return audioBytes.readUInt32LE(i + 12);
    }
    i += 8 + chunkSize;
    if (chunkSize % 2 === 1) i++;
  }
  return 0;
}

/**
 * @param {Buffer} audioBytes
 * @returns {number}
 */
function effectiveSampleRate(audioBytes) {
  const fromFile = readPcmWavSampleRate(audioBytes);
  if (fromFile > 0) return fromFile;
  return 16000;
}

/**
 * @param {number} sampleRate
 * @returns {string[]}
 */
function contentTypeCandidates(sampleRate) {
  const sr = String(sampleRate);
  return [
    `audio/wav; codecs=audio/pcm; samplerate=${sr}`,
    `audio/wav; codec=audio/pcm; samplerate=${sr}`,
    `audio/wav; codecs=audio/pcm;samplerate=${sr}`,
    "audio/wav",
  ];
}

/**
 * @param {string} region
 * @param {string} language
 * @returns {URL}
 */
function sttUriFromRegion(region, language) {
  const url = new URL(
      `https://${region}.stt.speech.microsoft.com/speech/recognition/` +
      "conversation/cognitiveservices/v1",
  );
  url.searchParams.set("language", language);
  return url;
}

/**
 * @param {string} apiKey
 * @param {string} region
 * @param {Buffer} audioBytes
 * @param {string} language
 * @returns {Promise<string>}
 */
async function callAzureStt(apiKey, region, audioBytes, language) {
  if (!apiKey) {
    throw new Error("Azure Speech API key not configured");
  }
  if (!region) {
    throw new Error("Azure Speech region not configured");
  }
  if (!audioBytes || audioBytes.length === 0) {
    throw new Error("Audio file is empty");
  }

  const endpoint = sttUriFromRegion(region, language || "en-US");
  const sampleRate = effectiveSampleRate(audioBytes);
  const headersBase = {
    "Ocp-Apim-Subscription-Key": apiKey,
    "Accept": "application/json",
  };

  let lastBody = "";
  let lastCode = 0;

  for (const contentType of contentTypeCandidates(sampleRate)) {
    const response = await fetch(endpoint.toString(), {
      method: "POST",
      headers: {...headersBase, "Content-Type": contentType},
      body: audioBytes,
    });
    const bodyText = await response.text();
    lastCode = response.status;
    lastBody = bodyText;

    if (response.ok) {
      let data;
      try {
        data = JSON.parse(bodyText);
      } catch {
        throw new Error(`Azure STT invalid JSON: ${bodyText.slice(0, 200)}`);
      }
      const displayText = data?.DisplayText ??
        data?.NBest?.[0]?.Display ??
        data?.NBest?.[0]?.Lexical;
      if (!displayText || !String(displayText).trim()) {
        throw new Error("Empty transcription result from Azure STT");
      }
      return String(displayText).trim();
    }

    if (response.status === 415) {
      continue;
    }

    if (response.status === 429) {
      const err = new Error(`Azure STT rate limit: ${bodyText}`);
      err.code = "RATE_LIMIT";
      throw err;
    }

    throw new Error(`Azure STT error ${response.status}: ${bodyText.slice(0, 300)}`);
  }

  throw new Error(
      `Azure STT rejected audio (415). Last: ${lastCode} ` +
      `${lastBody.slice(0, 200)}`,
  );
}

module.exports = {callAzureStt, effectiveSampleRate};
