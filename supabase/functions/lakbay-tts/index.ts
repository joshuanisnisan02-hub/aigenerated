const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const suppliedKey = req.headers.get('apikey')?.trim() ?? '';
    const publishableKeysRaw = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}';
    const publishableKeys = JSON.parse(publishableKeysRaw) as Record<string, string>;
    const allowedKeys = Object.values(publishableKeys);

    if (!suppliedKey || !allowedKeys.includes(suppliedKey)) {
      return json({ error: 'Invalid Supabase publishable key.' }, 401);
    }

    const { text } = await req.json();
    if (typeof text !== 'string' || text.trim().length === 0) {
      return json({ error: 'Text is required.' }, 400);
    }

    const safeText = normalizeFilipinoSpeech(text).slice(0, 1800);

    // Primary provider: ElevenLabs. If the account is out of credits/quota,
    // automatically fall back to Gemini TTS so the live app continues speaking.
    const elevenKey = Deno.env.get('ELEVENLABS_API_KEY')?.trim() ?? '';
    const voiceId = Deno.env.get('ELEVENLABS_VOICE_ID')?.trim() ?? '';

    if (elevenKey && voiceId) {
      const elevenResult = await synthesizeElevenLabs(safeText, elevenKey, voiceId);
      if (elevenResult.ok) {
        return audioResponse(elevenResult.bytes, 'audio/mpeg', 'elevenlabs');
      }

      console.error(
        `ElevenLabs failed (${elevenResult.status}). Falling back to Gemini TTS: ${elevenResult.details.slice(0, 600)}`,
      );
    }

    const geminiKey = Deno.env.get('GEMINI_API_KEY')?.trim() ?? '';
    if (!geminiKey) {
      return json({
        error: 'Voice providers are unavailable.',
        details: 'ElevenLabs could not generate audio and GEMINI_API_KEY is not configured.',
      }, 503);
    }

    const geminiResult = await synthesizeGeminiTts(safeText, geminiKey);
    if (!geminiResult.ok) {
      return json({
        error: 'Hindi makagawa ng Filipino voice sa ngayon.',
        status: geminiResult.status,
        details: geminiResult.details,
      }, 502);
    }

    return audioResponse(geminiResult.bytes, 'audio/wav', 'gemini-tts');
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

async function synthesizeElevenLabs(
  text: string,
  apiKey: string,
  voiceId: string,
): Promise<{ ok: true; bytes: Uint8Array; status: number; details: string } | { ok: false; bytes: Uint8Array; status: number; details: string }> {
  const endpoint = `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceId)}?output_format=mp3_44100_128`;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'xi-api-key': apiKey,
      'Content-Type': 'application/json',
      'Accept': 'audio/mpeg',
    },
    body: JSON.stringify({
      text,
      model_id: 'eleven_flash_v2_5',
      language_code: 'fil',
      voice_settings: {
        stability: 0.50,
        similarity_boost: 0.74,
        style: 0.08,
        use_speaker_boost: true,
      },
    }),
  });

  if (!response.ok) {
    return {
      ok: false,
      bytes: new Uint8Array(),
      status: response.status,
      details: await response.text(),
    };
  }

  return {
    ok: true,
    bytes: new Uint8Array(await response.arrayBuffer()),
    status: 200,
    details: '',
  };
}

async function synthesizeGeminiTts(
  text: string,
  apiKey: string,
): Promise<{ ok: true; bytes: Uint8Array; status: number; details: string } | { ok: false; bytes: Uint8Array; status: number; details: string }> {
  const endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent';
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: JSON.stringify({
      contents: [
        {
          parts: [
            {
              text: `Basahin nang natural na Filipino/Tagalog, malinaw, magiliw, at parang isang nakatatandang gurong Pilipino na nagkukuwento ng kasaysayan. Huwag baguhin ang mensahe. Bigkasin nang maayos ang mga pangalang Pilipino at ang mga bilang sa paraang Filipino.\n\n${text}`,
            },
          ],
        },
      ],
      generationConfig: {
        responseModalities: ['AUDIO'],
        speechConfig: {
          voiceConfig: {
            prebuiltVoiceConfig: {
              voiceName: 'Kore',
            },
          },
        },
      },
    }),
  });

  if (!response.ok) {
    return {
      ok: false,
      bytes: new Uint8Array(),
      status: response.status,
      details: await response.text(),
    };
  }

  const data = await response.json();
  const parts = data?.candidates?.[0]?.content?.parts;
  const audioPart = Array.isArray(parts)
    ? parts.find((part: any) => part?.inlineData?.data)
    : null;
  const encoded = audioPart?.inlineData?.data;
  const mimeType = String(audioPart?.inlineData?.mimeType ?? 'audio/L16;codec=pcm;rate=24000').toLowerCase();

  if (!encoded || typeof encoded !== 'string') {
    return {
      ok: false,
      bytes: new Uint8Array(),
      status: 200,
      details: 'Gemini TTS returned no audio payload.',
    };
  }

  const pcm = base64ToBytes(encoded);
  const sampleRateMatch = mimeType.match(/rate=(\d+)/i);
  const sampleRate = sampleRateMatch ? Number(sampleRateMatch[1]) : 24000;
  const wav = pcmToWav(pcm, sampleRate, 1, 16);

  return { ok: true, bytes: wav, status: 200, details: '' };
}

function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function pcmToWav(pcm: Uint8Array, sampleRate = 24000, channels = 1, bitsPerSample = 16): Uint8Array {
  const headerSize = 44;
  const buffer = new ArrayBuffer(headerSize + pcm.length);
  const view = new DataView(buffer);
  const out = new Uint8Array(buffer);

  writeAscii(view, 0, 'RIFF');
  view.setUint32(4, 36 + pcm.length, true);
  writeAscii(view, 8, 'WAVE');
  writeAscii(view, 12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, channels, true);
  view.setUint32(24, sampleRate, true);
  const byteRate = sampleRate * channels * (bitsPerSample / 8);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, channels * (bitsPerSample / 8), true);
  view.setUint16(34, bitsPerSample, true);
  writeAscii(view, 36, 'data');
  view.setUint32(40, pcm.length, true);
  out.set(pcm, headerSize);
  return out;
}

function writeAscii(view: DataView, offset: number, text: string) {
  for (let i = 0; i < text.length; i++) view.setUint8(offset + i, text.charCodeAt(i));
}

function audioResponse(bytes: Uint8Array, contentType: string, provider: string): Response {
  return new Response(bytes, {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': contentType,
      'Cache-Control': 'no-store',
      'X-Lakbay-Voice-Provider': provider,
    },
  });
}

function normalizeFilipinoSpeech(input: string): string {
  let value = input
    .replace(/\r/g, '')
    .replace(/https?:\/\/\S+/gi, '')
    .replace(/[*_#>`]/g, '')
    .replace(/📚[^\n]*/gi, '')
    .replace(/\n{2,}/g, '. ')
    .replace(/\n/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (/^Mabuhay! Ako si Lakbay Kasaysayan AI,/i.test(value)) {
    value = value.replace(
      /^Mabuhay! Ako si Lakbay Kasaysayan AI, ang iyong gabay sa Kasaysayan ng Pilipinas\. Maaari mo akong tanungin tungkol sa mga tao, lugar, pangyayari, at mahahalagang bahagi ng ating kasaysayan\. Ano ang gusto mong malaman\?/i,
      'Mabuhay. Ako si Lakbay Kasaysayan. Ako ang inyong gabay sa kasaysayan ng Pilipinas. Maaari ninyo akong tanungin tungkol sa mga tao, lugar, pangyayari, at mahahalagang bahagi ng ating kasaysayan. Ano ang nais ninyong malaman?',
    );
  }

  const aliases: Array<[RegExp, string]> = [
    [/\bLakbay Kasaysayan AI\b/gi, 'Lakbay Kasaysayan'],
    [/\bAI\b/g, 'artipisyal na intelihensiya'],
    [/\bDr\.\s*Jose Rizal\b/gi, 'Doktor Hosé Rizal'],
    [/\bJose Rizal\b/gi, 'Hosé Rizal'],
    [/\bJosé Rizal\b/gi, 'Hosé Rizal'],
    [/\bAndres Bonifacio\b/gi, 'Andrés Bonifásyo'],
    [/\bAndrés Bonifacio\b/gi, 'Andrés Bonifásyo'],
    [/\bEmilio Aguinaldo\b/gi, 'Emílyo Aginaldo'],
    [/\bApolinario Mabini\b/gi, 'Apolináryo Mabíni'],
    [/\bMarcelo H\. del Pilar\b/gi, 'Marsélo H. del Pilár'],
    [/\bLapu[ -]?Lapu\b/gi, 'Lapu-Lapu'],
    [/\bLapulapu\b/gi, 'Lapu-Lapu'],
    [/\bFerdinand Magellan\b/gi, 'Ferdinand Magelyán'],
    [/\bEDSA\b/g, 'Edsa'],
    [/\bWWII\b/gi, 'Ikalawang Digmaang Pandaigdig'],
    [/\bWorld War II\b/gi, 'Ikalawang Digmaang Pandaigdig'],
    [/\bMartial Law\b/gi, 'Batas Militar'],
    [/\bNHCP\b/g, 'N H C P'],
  ];

  for (const [pattern, replacement] of aliases) value = value.replace(pattern, replacement);
  value = replaceNumbersForSpeech(value);

  return value
    .replace(/\s+-\s+/g, ', ')
    .replace(/;\s*/g, ', ')
    .replace(/\.\s*\./g, '.')
    .replace(/\s+([,.!?])/g, '$1')
    .trim();
}

function replaceNumbersForSpeech(input: string): string {
  return input.replace(/\b(?:\d{1,3}(?:,\d{3})+|\d+)\b/g, (raw) => {
    const n = Number(raw.replace(/,/g, ''));
    if (!Number.isSafeInteger(n) || n < 0 || n > 999999) return raw;
    return filipinoNumber(n, n < 100);
  });
}

function filipinoNumber(n: number, conversationalUnder100 = false): string {
  if (n === 0) return 'sero';
  if (conversationalUnder100 && n >= 20 && n < 100) return conversationalTens(n);
  if (n < 100) return nativeUnder100(n);
  if (n < 1000) return nativeUnder1000(n);

  if (n < 10000) {
    const thousands = Math.floor(n / 1000);
    const rest = n % 1000;
    const first = `${linkerForUnit(thousands)} libo`;
    if (rest === 0) return first;

    const hundreds = Math.floor(rest / 100);
    const last = rest % 100;
    if (hundreds > 0 && last > 0) return `${first}, ${hundredsText(hundreds)}, at ${nativeUnder100(last)}`;
    if (hundreds > 0) return `${first}, ${hundredsText(hundreds)}`;
    return `${first}, ${nativeUnder100(last)}`;
  }

  const thousands = Math.floor(n / 1000);
  const rest = n % 1000;
  const thousandText = `${nativeUnder1000(thousands)} libo`;
  if (rest === 0) return thousandText;
  return `${thousandText}, ${nativeUnder1000(rest)}`;
}

function conversationalTens(n: number): string {
  const tens = Math.floor(n / 10) * 10;
  const ones = n % 10;
  if (ones === 0) return nativeUnder100(n);

  const tensWords: Record<number, string> = {
    20: 'bente', 30: 'trenta', 40: 'kuwarenta', 50: 'singkuwenta',
    60: 'sesenta', 70: 'setenta', 80: 'otsenta', 90: 'nobenta',
  };
  const onesWords = ['', 'uno', 'dos', 'tres', 'kuwatro', 'singko', 'sais', 'siyete', 'otso', 'nuwebe'];
  return `${tensWords[tens]} ${onesWords[ones]}`;
}

function nativeUnder100(n: number): string {
  const ones = ['sero', 'isa', 'dalawa', 'tatlo', 'apat', 'lima', 'anim', 'pito', 'walo', 'siyam'];
  const teens: Record<number, string> = {
    10: 'sampu', 11: 'labing-isa', 12: 'labindalawa', 13: 'labintatlo',
    14: 'labing-apat', 15: 'labinlima', 16: 'labing-anim', 17: 'labimpito',
    18: 'labingwalo', 19: 'labinsiyam',
  };
  if (n < 10) return ones[n];
  if (n < 20) return teens[n];

  const tens = Math.floor(n / 10);
  const unit = n % 10;
  const tensWords: Record<number, string> = {
    2: 'dalawampu', 3: 'tatlumpu', 4: 'apatnapu', 5: 'limampu',
    6: 'animnapu', 7: 'pitumpu', 8: 'walumpu', 9: 'siyamnapu',
  };
  if (unit === 0) return tensWords[tens];
  return `${tensWords[tens]}'t ${ones[unit]}`;
}

function nativeUnder1000(n: number): string {
  if (n < 100) return nativeUnder100(n);
  const hundreds = Math.floor(n / 100);
  const rest = n % 100;
  const hundredPart = hundredsText(hundreds);
  if (rest === 0) return hundredPart;
  return `${hundredPart}, at ${nativeUnder100(rest)}`;
}

function hundredsText(n: number): string {
  const forms: Record<number, string> = {
    1: 'isang daan', 2: 'dalawang daan', 3: 'tatlong daan', 4: 'apat na raan',
    5: 'limang daan', 6: 'anim na raan', 7: 'pitong daan', 8: 'walong daan', 9: 'siyam na raan',
  };
  return forms[n];
}

function linkerForUnit(n: number): string {
  const forms: Record<number, string> = {
    1: 'isang', 2: 'dalawang', 3: 'tatlong', 4: 'apat na', 5: 'limang',
    6: 'anim na', 7: 'pitong', 8: 'walong', 9: 'siyam na',
  };
  return forms[n] ?? nativeUnder100(n);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
