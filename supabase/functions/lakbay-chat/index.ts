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
    const systemPrompt = `Ikaw si Lakbay Kasaysayan AI, isang magiliw, matalino, at mapagkakatiwalaang gabay sa Kasaysayan ng Pilipinas.

MGA PANUNTUNAN:
- Pangunahing wika: Filipino/Tagalog.
- Sagutin muna nang direkta ang tanong bago magbigay ng dagdag na paliwanag.
- Saklaw mo ang buong kasaysayan ng Pilipinas at hindi ka limitado sa question bank.
- Huwag mag-imbento ng petsa, tao, batas, quote, source, URL, o dokumento.
- Kapag may kontrobersiya, sabihin: "May iba't ibang interpretasyon ang mga historyador tungkol dito." at ilahad nang patas ang mahahalagang pananaw.
- Kapag hindi sapat ang katiyakan, sabihin: "Hindi ako lubos na sigurado sa impormasyong ito. Mas mabuting kumpirmahin natin ito gamit ang mapagkakatiwalaang sanggunian."
- Ihiwalay kung kinakailangan ang napatunayang pangyayari, interpretasyon, alamat, at pinagtatalunang pahayag.
- Huwag gawing partisan o propagandistiko ang sagot.
- Para sa makabuluhang sagot, magdagdag ng "📚 Sanggunian / Maaaring Basahin" na may 1 hanggang 3 tunay at maaasahang source names lamang kung kumpiyansa ka sa mga ito.
- Panatilihing malinaw at angkop sa mag-aaral ang paliwanag, karaniwang 2 hanggang 5 maiikling talata.
- Kung ang tanong ay hindi tungkol sa Pilipinas o kasaysayan, magalang na ibalik ang usapan sa Kasaysayan ng Pilipinas.`;

    if (geminiKey) {
      const models = ['gemini-2.5-flash', 'gemini-2.5-flash-lite'];
      for (const model of models) {
        try {
          const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(geminiKey)}`;
          const response = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              system_instruction: { parts: [{ text: systemPrompt }] },
              contents: [{ role: 'user', parts: [{ text: question }] }],
              generationConfig: { maxOutputTokens: 900 },
            }),
          });

          if (response.ok) {
            const data = await response.json();
            const candidates = Array.isArray(data?.candidates) ? data.candidates : [];
            const parts = candidates[0]?.content?.parts;
            const answer = Array.isArray(parts)
              ? parts.map((p: { text?: string }) => p?.text ?? '').join('').trim()
              : '';
            if (answer) return json({ answer, model, source: 'gemini' });
          } else {
            const details = await response.text();
            console.error(`Gemini ${model} failed: ${response.status} ${details.slice(0, 700)}`);
          }
        } catch (error) {
          console.error(`Gemini ${model} request error`, error);
        }
      }
    }

    // Independent fallback so students can still ask open Philippine-history
    // questions even when the Gemini key is unavailable, restricted, or over quota.
    const wiki = await wikipediaFallback(question);
    if (wiki) return json({ answer: wiki.answer, source: wiki.source, title: wiki.title });

    return json({
      error: 'Hindi makakuha ng live history answer sa ngayon.',
      code: 'history_sources_unavailable',
    }, 502);
  } catch (error) {
    console.error('lakbay-chat unexpected error', error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

async function wikipediaFallback(question: string): Promise<{answer: string; source: string; title: string} | null> {
  for (const lang of ['tl', 'en']) {
    try {
      const searchUrl = `https://${lang}.wikipedia.org/w/api.php?action=query&list=search&srsearch=${encodeURIComponent(question + ' Pilipinas history')}&srlimit=3&format=json&origin=*`;
      const searchResponse = await fetch(searchUrl, {
        headers: { 'User-Agent': 'LakbayKasaysayanAI/1.0 educational-history-tutor' },
      });
      if (!searchResponse.ok) continue;
      const searchData = await searchResponse.json();
      const results = searchData?.query?.search;
      if (!Array.isArray(results) || results.length === 0) continue;

      const title = String(results[0].title ?? '').trim();
      if (!title) continue;

      const extractUrl = `https://${lang}.wikipedia.org/w/api.php?action=query&prop=extracts&exintro=1&explaintext=1&redirects=1&titles=${encodeURIComponent(title)}&format=json&origin=*`;
      const extractResponse = await fetch(extractUrl, {
        headers: { 'User-Agent': 'LakbayKasaysayanAI/1.0 educational-history-tutor' },
      });
      if (!extractResponse.ok) continue;
      const extractData = await extractResponse.json();
      const pages = extractData?.query?.pages;
      if (!pages || typeof pages !== 'object') continue;
      const page = Object.values(pages)[0] as { extract?: string } | undefined;
      const extract = page?.extract?.replace(/\s+/g, ' ').trim() ?? '';
      if (extract.length < 80) continue;

      const short = extract.length > 900 ? `${extract.slice(0, 900).replace(/\s+\S*$/, '')}…` : extract;
      const intro = lang === 'tl'
        ? `Batay sa sangguniang nahanap ko tungkol sa “${title}”: `
        : `Narito ang maikling paliwanag batay sa sangguniang nahanap ko tungkol sa “${title}”: `;
      const note = lang === 'tl'
        ? '\n\n📚 Sanggunian / Maaaring Basahin\n- Wikipedia (Filipino), artikulong: ' + title
        : '\n\n📚 Sanggunian / Maaaring Basahin\n- Wikipedia, article: ' + title;
      return { answer: `${intro}${short}${note}`, source: `wikipedia-${lang}`, title };
    } catch (error) {
      console.error(`Wikipedia ${lang} fallback failed`, error);
    }
  }
  return null;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
