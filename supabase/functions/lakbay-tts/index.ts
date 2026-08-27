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

    const safeText = text.trim().slice(0, 1800);
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
        voice_settings: {
          stability: 0.48,
          similarity_boost: 0.78,
          style: 0.18,
          use_speaker_boost: true,
        },
      }),
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

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
