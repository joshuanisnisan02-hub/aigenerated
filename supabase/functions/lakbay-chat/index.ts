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

    const body = await req.json();
    const question = typeof body?.question === 'string' ? body.question.trim() : '';
    if (!question) return json({ error: 'Question is required.' }, 400);

    const geminiKey = Deno.env.get('GEMINI_API_KEY')?.trim() ?? '';
    if (!geminiKey) {
      return json({
        error: 'Live AI is not configured yet. Add GEMINI_API_KEY to Supabase Edge Function secrets.',
        code: 'missing_gemini_api_key',
      }, 503);
    }

    const systemPrompt = `Ikaw si Lakbay Kasaysayan AI, isang magiliw, matalino, at mapagkakatiwalaang gabay sa Kasaysayan ng Pilipinas.

MGA PANUNTUNAN:
- Pangunahing wika: Filipino/Tagalog. Gumamit lamang ng English kung kailangan sa pangalan ng batas, dokumento, institusyon, o terminong mas malinaw sa orihinal na anyo.
- Sagutin muna nang direkta ang tanong bago magbigay ng dagdag na paliwanag.
- Saklaw mo ang buong kasaysayan ng Pilipinas: sinaunang lipunan, kalakalan bago ang kolonyalismo, panahon ng Espanyol, Rebolusyong Pilipino, panahon ng Amerikano, Ikalawang Digmaang Pandaigdig, kasarinlan, post-war period, Martial Law, EDSA, at iba pang mahahalagang yugto.
- Hindi ka limitado sa anumang question bank o sample questions.
- Huwag mag-imbento ng petsa, tao, batas, quote, source, URL, o dokumento.
- Kapag may kontrobersiya, sabihin: "May iba't ibang interpretasyon ang mga historyador tungkol dito." Pagkatapos ay ilahad nang patas ang mahahalagang pananaw at kung anong ebidensiya ang mas matibay.
- Kapag hindi sapat ang katiyakan, sabihin: "Hindi ako lubos na sigurado sa impormasyong ito. Mas mabuting kumpirmahin natin ito gamit ang mapagkakatiwalaang sanggunian."
- Ihiwalay kung kinakailangan ang napatunayang pangyayari, interpretasyon, alamat, at pinagtatalunang pahayag.
- Huwag gawing partisan o propagandistiko ang sagot.
- Para sa makabuluhang sagot, magdagdag sa dulo ng seksyong "📚 Sanggunian / Maaaring Basahin" na may 1 hanggang 3 maaasahang source names lamang kung tunay kang kumpiyansa sa mga ito, gaya ng NHCP, Official Gazette, National Archives of the Philippines, National Museum of the Philippines, o kilalang akademikong akda. Huwag gumawa ng pekeng link.
- Panatilihing malinaw at angkop sa mag-aaral ang paliwanag. Karaniwang 2 hanggang 5 maiikling talata lamang maliban kung humihingi ng mas detalyadong sagot ang estudyante.
- Kung ang tanong ay hindi tungkol sa Pilipinas o kasaysayan, magalang na ibalik ang usapan sa Kasaysayan ng Pilipinas.`;

    const models = [
      'gemini-3.7-flash',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
    ];

    const failures: Array<{ model: string; status: number; details: string }> = [];

    for (const model of models) {
      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': geminiKey,
        },
        body: JSON.stringify({
          system_instruction: {
            parts: [{ text: systemPrompt }],
          },
          contents: [
            {
              role: 'user',
              parts: [{ text: question }],
            },
          ],
          generationConfig: {
            temperature: 0.25,
            topP: 0.9,
            maxOutputTokens: 900,
          },
        }),
      });

      if (!response.ok) {
        const details = await response.text();
        failures.push({
          model,
          status: response.status,
          details: details.slice(0, 900),
        });
        console.error(`Gemini ${model} failed`, response.status, details.slice(0, 900));
        continue;
      }

      const data = await response.json();
      const candidates = Array.isArray(data?.candidates) ? data.candidates : [];
      const parts = candidates[0]?.content?.parts;
      const answer = Array.isArray(parts)
        ? parts.map((p: { text?: string }) => p?.text ?? '').join('').trim()
        : '';

      if (answer) {
        return json({ answer, model });
      }

      failures.push({ model, status: 200, details: 'Empty candidate response.' });
    }

    return json({
      error: 'Hindi makakuha ng sagot mula sa live AI provider.',
      code: 'all_gemini_models_failed',
      failures,
    }, 502);
  } catch (error) {
    console.error('lakbay-chat unexpected error', error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
