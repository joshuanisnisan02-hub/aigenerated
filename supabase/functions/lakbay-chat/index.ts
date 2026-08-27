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
        error: 'Hindi naka-configure ang live history service.',
        code: 'missing_gemini_api_key',
      }, 503);
    }

    const trustedContext = buildTrustedContext(question);
    const systemPrompt = `Ikaw si Lakbay Kasaysayan AI, isang maingat, magiliw, at mapagkakatiwalaang tutor sa Kasaysayan ng Pilipinas.

MGA PANUNTUNAN:
- Pangunahing wika: natural na Filipino/Tagalog.
- Sagutin ang EKSAKTONG tanong ng estudyante. Huwag lumihis sa ibang paksa.
- Hindi ka limitado sa question bank.
- Huwag mag-imbento ng pangalan, petsa, relasyon, batas, sipi, source, URL, o dokumento.
- Para sa biographical at personal-history questions, huwag tawaging "kasintahan" ang isang tao kung ang ebidensiya ay nagpapakita lamang ng paghanga, panliligaw, pagkakaibigan, o maikling pagkakaugnay.
- Kung magkakaiba ang historical accounts, sabihin: "May iba't ibang interpretasyon ang mga historyador tungkol dito." at ipaliwanag nang maikli ang pagkakaiba.
- Kung hindi sapat ang ebidensiya, sabihin kung alin lang ang matibay na dokumentado. Huwag punan ang kakulangan gamit ang hula.
- Huwag gawing partisan o propagandistiko ang sagot.
- Panatilihing malinaw at angkop sa mag-aaral ang paliwanag. Karaniwang 2 hanggang 4 maiikling talata.
- Sa dulo, maglagay ng "📚 Sanggunian / Maaaring Basahin" at ilista lamang ang mga source names na talagang ibinigay sa TRUSTED CONTEXT o mga kilalang primary/official sources na lubos kang kumpiyansa.
- Kung ang tanong ay hindi tungkol sa Pilipinas o kasaysayan, magalang na ibalik ang usapan sa Kasaysayan ng Pilipinas.`;

    const draftPrompt = `Tanong ng estudyante: ${question}

${trustedContext ? `TRUSTED CONTEXT:\n${trustedContext}\n\nGamitin ito bilang pangunahing batayan. Huwag salungatin ito nang walang malinaw na dahilan.` : ''}

Sagutin nang direkta, maingat, at pang-estudyante. Kung may terminong malabo gaya ng "kasintahan," linawin ang pagkakaiba ng dokumentadong pag-ibig, panliligaw, at mga babaeng karaniwang iniuugnay lamang sa tao.`;

    const models = [
      'gemini-3.6-flash',
      'gemini-3.5-flash',
      'gemini-3.5-flash-lite',
      'gemini-2.5-flash',
    ];

    const failures: Array<{ model: string; status: number; details: string }> = [];

    for (const model of models) {
      const draftResult = await callGemini({
        apiKey: geminiKey,
        model,
        systemPrompt,
        userPrompt: draftPrompt,
        maxOutputTokens: 900,
      });

      if (!draftResult.ok) {
        failures.push({ model, status: draftResult.status, details: draftResult.details });
        continue;
      }

      let answer = draftResult.text;

      // A second pass acts as an editor/fact-checker without requiring paid
      // Google Search grounding. It is especially useful for names, dates,
      // relationships, and disputed historical claims.
      const verifyPrompt = `Suriin ang sagot sa ibaba bago ito ibigay sa estudyante.

ORIHINAL NA TANONG:
${question}

${trustedContext ? `TRUSTED CONTEXT:\n${trustedContext}\n` : ''}
DRAFT NA SAGOT:
${answer}

Gawain:
1. Tanggalin o itama ang anumang claim na posibleng imbento, sobra ang katiyakan, hindi tumutugon sa tanong, o maling nag-uuri ng relasyon/pangyayari.
2. Panatilihin lamang ang mga detalyeng mataas ang kumpiyansa.
3. Kung may magkakaibang historical accounts, sabihin iyon nang malinaw.
4. Ibalik ang FINAL ANSWER lamang sa natural na Filipino, kasama ang maikling Sanggunian section. Huwag banggitin ang prosesong ito.`;

      const checked = await callGemini({
        apiKey: geminiKey,
        model,
        systemPrompt,
        userPrompt: verifyPrompt,
        maxOutputTokens: 950,
      });

      if (checked.ok && checked.text.trim().length > 0) {
        answer = checked.text.trim();
      }

      return json({
        answer,
        model,
        source: trustedContext ? 'gemini-verified-with-trusted-context' : 'gemini-verified',
      });
    }

    const deterministic = deterministicFallback(question);
    if (deterministic) return json({ answer: deterministic, source: 'trusted-local-fallback' });

    return json({
      answer: 'Hindi ako lubos na sigurado sa impormasyong ito. Mas mabuting kumpirmahin natin ito gamit ang mapagkakatiwalaang sanggunian bago ako magbigay ng tiyak na sagot.',
      code: 'gemini_unavailable',
      failures,
    }, 200);
  } catch (error) {
    console.error('lakbay-chat unexpected error', error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

async function callGemini(args: {
  apiKey: string;
  model: string;
  systemPrompt: string;
  userPrompt: string;
  maxOutputTokens: number;
}): Promise<{ ok: true; text: string; status: number; details: string } | { ok: false; text: string; status: number; details: string }> {
  try {
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${args.model}:generateContent`;
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': args.apiKey,
      },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: args.systemPrompt }] },
        contents: [{ role: 'user', parts: [{ text: args.userPrompt }] }],
        generationConfig: {
          temperature: 0.12,
          topP: 0.85,
          maxOutputTokens: args.maxOutputTokens,
        },
      }),
    });

    if (!response.ok) {
      const details = (await response.text()).slice(0, 1000);
      console.error(`Gemini ${args.model} failed: ${response.status} ${details}`);
      return { ok: false, text: '', status: response.status, details };
    }

    const data = await response.json();
    const candidates = Array.isArray(data?.candidates) ? data.candidates : [];
    const parts = candidates[0]?.content?.parts;
    const text = Array.isArray(parts)
      ? parts.map((p: { text?: string }) => p?.text ?? '').join('').trim()
      : '';

    if (!text) {
      return { ok: false, text: '', status: 200, details: 'Empty candidate response.' };
    }

    return { ok: true, text, status: 200, details: '' };
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    console.error(`Gemini ${args.model} request error`, error);
    return { ok: false, text: '', status: 0, details };
  }
}

function buildTrustedContext(question: string): string {
  const q = question.toLowerCase();

  if (q.includes('rizal') && /(kasintahan|girlfriend|pag-ibig|pagibig|love life|naging babae|mga babae)/i.test(q)) {
    return `Paksa: Mga pag-ibig at relasyong romantiko ni Jose Rizal.

MGA MATIBAY NA PUNTONG MAAARING GAMITIN:
- Ang historical marker ng Concordia College sa NHCP registry ay tahasang nagsasabing doon nakilala ni Rizal ang kanyang "unang pag-ibig" na si Segunda Katigbak, at si Leonor Rivera na "pinag-ukulan niya ng tunay na pagmamahal."
- Ang National Museum of the Philippines, sa paglalarawan ng obra ni Rizal na "Josephine Sleeping," ay tumutukoy kay Josephine Bracken bilang "his last love."
- Sa isang NHCP FOI response tungkol kina Rizal at Josephine Bracken, itinuro ng NHCP ang akda ni Austin Craig, Lineage, Life and Labors of José Rizal, Philippine Patriot, bilang sanggunian para sa kanilang relasyon.

MAHALAGANG PAG-IINGAT:
- Maraming popular na listahan ang nagsasama ng iba pang babaeng nakilala, hinangaan, niligawan, o nakaugnay kay Rizal. Huwag awtomatikong tawagin silang lahat na pormal na "kasintahan" kung walang sapat na ebidensiya.
- Kung magbabanggit ng iba pang pangalan, ilagay sila sa hiwalay na kategoryang "iba pang babaeng romantikong iniuugnay kay Rizal" at ipaliwanag na nag-iiba ang klasipikasyon depende sa historyador/source.

MGA SANGGUNIANG PANGALAN NA MAAARING ILAGAY:
- National Historical Commission of the Philippines (NHCP), Concordia College historical marker registry
- National Museum of the Philippines, "Josephine Sleeping"
- Austin Craig, Lineage, Life and Labors of José Rizal, Philippine Patriot`;
  }

  if (q.includes('pugad lawin') || q.includes('balintawak')) {
    return `Paksa: Sigaw ng Pugad Lawin / Balintawak.
- May iba't ibang salaysay tungkol sa eksaktong lugar at petsa ng "Sigaw," kaya huwag magkunwaring iisa lamang ang walang-kontrobersiyang bersyon.
- Iugnay ito sa hayagang pagputol ng mga Katipunero sa kolonyal na kapangyarihan at sa pagsisimula ng rebolusyonaryong pag-aaklas noong Agosto 1896.
- Kapag binanggit ang pagpunit ng cedula, ipaliwanag na bahagi ito ng mga salaysay tungkol sa pangyayari ngunit may pagkakaiba ang testimonya sa petsa at lokasyon.
Sanggunian: National Historical Commission of the Philippines (NHCP); mga memoir/testimonya ng Katipunero gaya ni Pio Valenzuela.`;
  }

  return '';
}

function deterministicFallback(question: string): string | null {
  const q = question.toLowerCase();

  if (q.includes('rizal') && /(kasintahan|girlfriend|pag-ibig|pagibig|love life|naging babae|mga babae)/i.test(q)) {
    return `Hindi lahat ng babaeng karaniwang iniuugnay kay Jose Rizal ay maituturing na pormal na “kasintahan” sa modernong kahulugan. Sa mga mas matibay na pampublikong sanggunian, tatlong relasyong malinaw na mailalarawan ay sina Segunda Katigbak, Leonor Rivera, at Josephine Bracken.

Si Segunda Katigbak ay tinutukoy sa NHCP historical marker ng Concordia College bilang unang pag-ibig ni Rizal. Si Leonor Rivera naman ay inilalarawan sa marker na pinag-ukulan niya ng tunay na pagmamahal. Si Josephine Bracken ang naging kapareha niya sa Dapitan at tinutukoy ng National Museum of the Philippines bilang kanyang “last love.”

May iba pang babaeng madalas isama sa popular na mga listahan tungkol sa love life ni Rizal, ngunit nagkakaiba ang mga historyador kung dapat silang tawaging kasintahan, niligawan, hinangaan, o romantikong nakaugnay lamang. Kaya mas maingat na huwag silang pagsama-samahin sa iisang kategorya nang walang paliwanag.

📚 Sanggunian / Maaaring Basahin
- National Historical Commission of the Philippines (NHCP), Concordia College historical marker registry
- National Museum of the Philippines, “Josephine Sleeping”
- Austin Craig, Lineage, Life and Labors of José Rizal, Philippine Patriot`;
  }

  return null;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
