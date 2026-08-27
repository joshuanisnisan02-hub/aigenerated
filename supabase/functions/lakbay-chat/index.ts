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
        error: 'Hindi naka-configure ang live history research service.',
        code: 'missing_gemini_api_key',
      }, 503);
    }

    const systemPrompt = `Ikaw si Lakbay Kasaysayan AI, isang maingat, magiliw, at mapagkakatiwalaang tutor sa Kasaysayan ng Pilipinas.

LAYUNIN:
Sagutin ang eksaktong tanong ng estudyante gamit ang mapagkakatiwalaang ebidensiya. Hindi ka limitado sa question bank. Gumamit ng Google Search grounding kapag kailangan upang ma-verify ang sagot.

MGA PANUNTUNAN SA KATUMPAKAN:
- Pangunahing wika: natural na Filipino/Tagalog.
- Sagutin muna nang direkta ang tanong. Huwag magbigay ng impormasyong hindi hinihingi kung hindi kailangan sa paliwanag.
- Unawain muna kung ano talaga ang hinihingi ng tanong bago magsaliksik. Halimbawa, kung ang tanong ay tungkol sa mga naging kasintahan ni Jose Rizal, huwag sagutin gamit ang artikulo tungkol sa Noli Me Tangere.
- Bago magbigay ng tiyak na pangalan, petsa, relasyon, batas, sipi, o bilang, i-cross-check ito sa higit sa isang mapagkakatiwalaang sanggunian kung posible.
- Unahin ang mga sangguniang ito: National Historical Commission of the Philippines (NHCP), Official Gazette of the Republic of the Philippines, National Archives of the Philippines, National Museum of the Philippines, university publications, peer-reviewed academic works, at kinikilalang historical reference works.
- Huwag gumamit ng isang random o hindi kaugnay na search result bilang batayan ng sagot.
- Wikipedia ay maaari lamang maging panimulang sanggunian. Huwag itong gawing nag-iisang batayan para sa sensitibo, kontrobersyal, personal, o biographical na claim.
- Para sa mga personal na relasyon, pag-ibig, pamilya, tsismis, o disputed biography: malinaw na paghiwalayin ang dokumentadong relasyon, malawak na tinatanggap na historical account, at mga alegasyon o kuwentong hindi sapat ang ebidensiya.
- Huwag mag-imbento ng pangalan, petsa, source, quote, URL, o dokumento.
- Kung salungat ang mga source, sabihin: "May iba't ibang interpretasyon ang mga historyador tungkol dito." at ipaliwanag kung saan sila nagkakaiba.
- Kung hindi sapat ang ebidensiya upang sagutin nang maaasahan, sabihin: "Hindi ako lubos na sigurado sa impormasyong ito. Mas mabuting kumpirmahin natin ito gamit ang mapagkakatiwalaang sanggunian." Huwag punan ang kakulangan gamit ang hula.
- Huwag gawing partisan o propagandistiko ang sagot.
- Panatilihing malinaw at angkop sa mag-aaral ang paliwanag. Karaniwang 2 hanggang 5 maiikling talata.
- Kung ang tanong ay hindi tungkol sa Pilipinas o kasaysayan, magalang na ibalik ang usapan sa Kasaysayan ng Pilipinas.

SANGGUNIAN:
Sa dulo, maglagay ng seksyong "📚 Sanggunian / Maaaring Basahin". Ilagay lamang ang mga source na talagang ginamit o nahanap sa grounded search. Huwag gumawa ng pekeng sanggunian.`;

    const models = ['gemini-2.5-flash', 'gemini-2.5-flash-lite'];
    const failures: Array<{ model: string; status: number; details: string }> = [];

    for (const model of models) {
      try {
        const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
        const response = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': geminiKey,
          },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: systemPrompt }] },
            contents: [
              {
                role: 'user',
                parts: [
                  {
                    text: `Tanong ng estudyante: ${question}\n\nSuriin muna kung anong uri ng impormasyon ang hinihingi. Mag-search at mag-cross-check ng kaugnay na sources bago sumagot.`,
                  },
                ],
              },
            ],
            tools: [{ google_search: {} }],
            generationConfig: {
              temperature: 0.1,
              topP: 0.85,
              maxOutputTokens: 1200,
            },
          }),
        });

        if (!response.ok) {
          const details = await response.text();
          failures.push({ model, status: response.status, details: details.slice(0, 800) });
          console.error(`Gemini ${model} failed: ${response.status} ${details.slice(0, 800)}`);
          continue;
        }

        const data = await response.json();
        const candidate = Array.isArray(data?.candidates) ? data.candidates[0] : null;
        const parts = candidate?.content?.parts;
        let answer = Array.isArray(parts)
          ? parts.map((p: { text?: string }) => p?.text ?? '').join('').trim()
          : '';

        if (!answer) {
          failures.push({ model, status: 200, details: 'Empty candidate response.' });
          continue;
        }

        const groundedSources = extractGroundingSources(candidate?.groundingMetadata);
        answer = ensureSourceSection(answer, groundedSources);

        return json({
          answer,
          model,
          source: 'gemini-google-search-grounded',
          grounded: groundedSources.length > 0,
          sources: groundedSources,
        });
      } catch (error) {
        const details = error instanceof Error ? error.message : String(error);
        failures.push({ model, status: 0, details });
        console.error(`Gemini ${model} request error`, error);
      }
    }

    // Accuracy-first behavior: do not return a loosely matched Wikipedia article
    // or a guessed answer when grounded research is unavailable.
    return json({
      answer: 'Hindi ako lubos na sigurado sa impormasyong ito. Mas mabuting kumpirmahin natin ito gamit ang mapagkakatiwalaang sanggunian bago ako magbigay ng tiyak na sagot.',
      code: 'grounded_history_research_unavailable',
      failures,
    }, 200);
  } catch (error) {
    console.error('lakbay-chat unexpected error', error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

type GroundedSource = {
  title: string;
  uri: string;
};

function extractGroundingSources(metadata: any): GroundedSource[] {
  const chunks = Array.isArray(metadata?.groundingChunks) ? metadata.groundingChunks : [];
  const seen = new Set<string>();
  const sources: GroundedSource[] = [];

  for (const chunk of chunks) {
    const title = String(chunk?.web?.title ?? '').trim();
    const uri = String(chunk?.web?.uri ?? '').trim();
    if (!title && !uri) continue;

    const key = `${title}|${uri}`.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    sources.push({ title: title || domainFromUrl(uri), uri });
    if (sources.length >= 4) break;
  }

  return sources;
}

function ensureSourceSection(answer: string, sources: GroundedSource[]): string {
  const cleaned = answer.trim();
  if (sources.length === 0 || /📚\s*Sanggunian\s*\/\s*Maaaring Basahin/i.test(cleaned)) {
    return cleaned;
  }

  const lines = sources.map((source) => `- ${source.title}`);
  return `${cleaned}\n\n📚 Sanggunian / Maaaring Basahin\n${lines.join('\n')}`;
}

function domainFromUrl(uri: string): string {
  try {
    return new URL(uri).hostname.replace(/^www\./, '');
  } catch (_) {
    return 'Web source';
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
