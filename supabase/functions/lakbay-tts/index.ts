const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

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
    const modelId = Deno.env.get('ELEVENLABS_MODEL_ID') ?? 'eleven_multilingual_v2';

    if (!apiKey) {
      return json({
        error: 'ElevenLabs is not configured. Set ELEVENLABS_API_KEY in Supabase Edge Function secrets.',
      }, 500);
    }

    if (!voiceId) {
      return json({
        error: 'No ElevenLabs voice is configured. Create a Voice Design voice in ElevenLabs and set ELEVENLABS_VOICE_ID in Supabase secrets.',
      }, 500);
    }

    const safeText = normalizeFilipinoSpeech(text).slice(0, 1800);
    const endpoint = `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceId)}?output_format=mp3_44100_128`;

    const body: Record<string, unknown> = {
      text: safeText,
      model_id: modelId,
      voice_settings: {
        stability: 0.42,
        similarity_boost: 0.78,
        style: 0.16,
        use_speaker_boost: true,
      },
    };

    if (modelId !== 'eleven_multilingual_v2') {
      body.language_code = 'fil';
    }

    const elevenResponse = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: JSON.stringify(body),
    });

    if (!elevenResponse.ok) {
      const details = await elevenResponse.text();

      if (elevenResponse.status === 400 && details.includes('free_users_not_allowed')) {
        return json({
          error: 'The selected ElevenLabs voice is not available through the API on the free plan. Create a voice with ElevenLabs Voice Design, then replace ELEVENLABS_VOICE_ID with that custom voice ID.',
          code: 'voice_not_available_on_free_plan',
        }, 400);
      }

      return json({
        error: 'ElevenLabs speech request failed.',
        status: elevenResponse.status,
        details,
      }, 502);
    }

    const audio = await elevenResponse.arrayBuffer();
    return new Response(audio, {
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

  // The welcome line is heard very often, so give the narrator a dedicated
  // speech-only version with clearer pauses and a Filipino-friendly reading of
  // the initials AI. The text displayed in Flutter is not changed.
  const welcomeStart = 'Mabuhay! Ako si Lakbay Kasaysayan AI,';
  if (value.startsWith(welcomeStart)) {
    value = value.replace(
      /^Mabuhay! Ako si Lakbay Kasaysayan AI, ang iyong gabay sa Kasaysayan ng Pilipinas\. Maaari mo akong tanungin tungkol sa mga tao, lugar, pangyayari, at mahahalagang bahagi ng ating kasaysayan\. Ano ang gusto mong malaman\?/i,
      'Mabuhay! Ako si Lakbay Kasaysayan, ey ay. Ako ang iyong gabay sa kasaysayan ng Pilipinas. Maaari mo akong tanungin tungkol sa mga tao, lugar, pangyayari, at mahahalagang bahagi ng ating kasaysayan. Ano ang gusto mong malaman?',
    );
  }

  // Speech-only aliases. The visible answer remains unchanged.
  const aliases: Array<[RegExp, string]> = [
    [/\bLakbay Kasaysayan AI\b/gi, 'Lakbay Kasaysayan, ey ay'],
    [/\bAI\b/g, 'ey ay'],
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

  for (const [pattern, replacement] of aliases) {
    value = value.replace(pattern, replacement);
  }

  value = value
    .replace(/\s+-\s+/g, ', ')
    .replace(/;\s*/g, ', ')
    .replace(/\.\s*\./g, '.')
    .replace(/\s+([,.!?])/g, '$1')
    .trim();

  return value;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
