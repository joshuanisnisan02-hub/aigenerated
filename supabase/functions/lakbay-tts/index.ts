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

    const speechKey = Deno.env.get('AZURE_SPEECH_KEY');
    const speechRegion = Deno.env.get('AZURE_SPEECH_REGION');
    const voice = Deno.env.get('AZURE_FILIPINO_VOICE') ?? 'fil-PH-AngeloNeural';

    if (!speechKey || !speechRegion) {
      return json({
        error: 'Azure Speech is not configured. Set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION in Supabase Edge Function secrets.',
      }, 500);
    }

    const safeText = escapeXml(text.trim().slice(0, 4500));

    const ssml = `<?xml version="1.0" encoding="UTF-8"?>
<speak version="1.0" xml:lang="fil-PH" xmlns="http://www.w3.org/2001/10/synthesis">
  <voice name="${voice}">
    <prosody rate="-7%" pitch="-2%" volume="+0%">
      ${safeText}
    </prosody>
  </voice>
</speak>`;

    const endpoint = `https://${speechRegion}.tts.speech.microsoft.com/cognitiveservices/v1`;
    const azureResponse = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Ocp-Apim-Subscription-Key': speechKey,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
        'User-Agent': 'LakbayKasaysayanAI',
      },
      body: ssml,
    });

    if (!azureResponse.ok) {
      const details = await azureResponse.text();
      return json({
        error: 'Azure Speech request failed.',
        status: azureResponse.status,
        details,
      }, 502);
    }

    const audio = await azureResponse.arrayBuffer();
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

function escapeXml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}
