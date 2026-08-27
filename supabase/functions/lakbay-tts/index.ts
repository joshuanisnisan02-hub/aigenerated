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

    const apiKey = Deno.env.get('ELEVENLABS_API_KEY');
    const voiceId = Deno.env.get('ELEVENLABS_VOICE_ID') ?? '';

    if (!apiKey) return json({ error: 'ElevenLabs is not configured.' }, 500);
    if (!voiceId) return json({ error: 'No ElevenLabs voice is configured.' }, 500);

    // Force a Filipino-capable model that accepts language_code. This avoids
    // ElevenLabs guessing an English reading for short Filipino sentences.
    const modelId = 'eleven_flash_v2_5';
    const safeText = normalizeFilipinoSpeech(text).slice(0, 1800);
    const endpoint = `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceId)}?output_format=mp3_44100_128`;

    const elevenResponse = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: JSON.stringify({
        text: safeText,
        model_id: modelId,
        language_code: 'fil',
        voice_settings: {
          stability: 0.50,
          similarity_boost: 0.74,
          style: 0.08,
          use_speaker_boost: true,
        },
      }),
    });

    if (!elevenResponse.ok) {
      const details = await elevenResponse.text();
      return json({
        error: 'ElevenLabs speech request failed.',
        status: elevenResponse.status,
        details,
      }, 502);
    }

    return new Response(await elevenResponse.arrayBuffer(), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'audio/mpeg',
        'Cache-Control': 'no-store',
      },
    });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

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

  // Dedicated speech copy for the welcome line. The text shown on-screen stays
  // unchanged, but the audio uses shorter Filipino clauses and no English-style
  // reading of the letters A-I.
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
    if (hundreds > 0 && last > 0) {
      return `${first}, ${hundredsText(hundreds)}, at ${nativeUnder100(last)}`;
    }
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
