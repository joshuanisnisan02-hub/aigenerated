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
    const minLength = minimumUsefulLength(question);

    const systemPrompt = `Ikaw si Lakbay Kasaysayan AI, isang maingat, magiliw, at mapagkakatiwalaang tutor sa Kasaysayan ng Pilipinas.

MGA PANUNTUNAN:
- Pangunahing wika: natural na Filipino/Tagalog.
- Sagutin ang EKSAKTONG tanong ng estudyante. Huwag lumihis sa ibang paksa.
- Hindi ka limitado sa question bank.
- Huwag mag-imbento ng pangalan, petsa, relasyon, batas, sipi, source, URL, o dokumento.
- Para sa karaniwang historical-event question, magbigay ng sapat na paliwanag: ano ang nangyari, sino ang mahalagang sangkot, at bakit mahalaga ang pangyayari. Karaniwang 2 hanggang 4 maiikling talata.
- Para sa simpleng fact question gaya ng petsa o lugar, puwedeng mas maikli ngunit dapat may isang maikling paliwanag.
- Para sa biographical at personal-history questions, huwag tawaging "kasintahan" ang isang tao kung ang ebidensiya ay nagpapakita lamang ng paghanga, panliligaw, pagkakaibigan, o maikling pagkakaugnay.
- Kung magkakaiba ang historical accounts, sabihin: "May iba't ibang interpretasyon ang mga historyador tungkol dito." at ipaliwanag nang maikli ang pagkakaiba.
- Kung hindi sapat ang ebidensiya, sabihin kung alin lang ang matibay na dokumentado. Huwag punan ang kakulangan gamit ang hula.
- Huwag gawing partisan o propagandistiko ang sagot.
- HUWAG gumamit ng Markdown bold, asterisks, hash headings, backticks, o tables. Plain readable text lamang dahil direktang ipinapakita ang sagot sa chat bubble.
- Huwag magsimula sa generic na pagbati gaya ng "Kumusta" maliban kung binati ka muna ng estudyante. Simulan agad sa sagot.
- Sa dulo ng makabuluhang sagot, maglagay ng "📚 Sanggunian / Maaaring Basahin" at ilista lamang ang mga source names na nasa TRUSTED CONTEXT o mga source na lubos kang kumpiyansa.
- Kung ang tanong ay hindi tungkol sa Pilipinas o kasaysayan, magalang na ibalik ang usapan sa Kasaysayan ng Pilipinas.`;

    const draftPrompt = `Tanong ng estudyante: ${question}

${trustedContext ? `TRUSTED CONTEXT:\n${trustedContext}\n\nGamitin ito bilang pangunahing batayan. Huwag salungatin ito nang walang malinaw na dahilan.` : ''}

Bumuo ng kumpleto ngunit madaling basahing sagot. Para sa historical event, huwag tumigil pagkatapos lamang banggitin ang petsa; ipaliwanag din ang pangyayari at kahalagahan nito. Gumamit ng plain text lamang, walang ** o iba pang Markdown emphasis.`;

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
        maxOutputTokens: 1400,
      });

      if (!draftResult.ok) {
        failures.push({ model, status: draftResult.status, details: draftResult.details });
        continue;
      }

      let draft = cleanAnswerText(draftResult.text);

      // If the first response is suspiciously short, ask the model to complete it
      // before any fact-checking pass. This prevents one-sentence/truncated cards.
      if (draft.length < minLength) {
        const expansion = await callGemini({
          apiKey: geminiKey,
          model,
          systemPrompt,
          userPrompt: `Palawakin at kumpletuhin ang sagot sa ibaba nang hindi nag-iimbento ng bagong detalye.\n\nTANONG:\n${question}\n\n${trustedContext ? `TRUSTED CONTEXT:\n${trustedContext}\n\n` : ''}KASALUKUYANG SAGOT:\n${draft}\n\nGumawa ng 2 hanggang 4 maiikling talata. Para sa pangyayari, ipaliwanag ang konteksto, pangunahing nangyari, at kahalagahan. Maglagay ng maikling Sanggunian section kung may mapagkakatiwalaang source names. Plain text lamang; walang Markdown bold o asterisks.`,
          maxOutputTokens: 1500,
        });
        if (expansion.ok && cleanAnswerText(expansion.text).length > draft.length) {
          draft = cleanAnswerText(expansion.text);
        }
      }

      const verifyPrompt = `Suriin ang sagot sa ibaba bago ito ibigay sa estudyante.

ORIHINAL NA TANONG:
${question}

${trustedContext ? `TRUSTED CONTEXT:\n${trustedContext}\n` : ''}
DRAFT NA SAGOT:
${draft}

Gawain:
1. Itama lamang ang maling o sobra ang katiyakang claim. Huwag paikliin ang sagot nang walang dahilan.
2. Panatilihin ang mahahalagang paliwanag, konteksto, at kahalagahan ng pangyayari.
3. Kung may magkakaibang historical accounts, sabihin iyon nang malinaw.
4. Panatilihin ang 2 hanggang 4 maiikling talata para sa historical-event questions.
5. Plain text lamang. Walang Markdown bold, asterisks, hash heading, o backticks.
6. Ibalik ang FINAL ANSWER lamang, kasama ang maikling Sanggunian section kapag naaangkop.`;

      const checked = await callGemini({
        apiKey: geminiKey,
        model,
        systemPrompt,
        userPrompt: verifyPrompt,
        maxOutputTokens: 1500,
      });

      let answer = draft;
      if (checked.ok) {
        const checkedText = cleanAnswerText(checked.text);
        // Do not accept a verifier result that accidentally collapses a useful
        // answer into a tiny fragment. Accuracy editing should preserve substance.
        const acceptableLength = Math.max(minLength, Math.floor(draft.length * 0.65));
        if (checkedText.length >= acceptableLength) {
          answer = checkedText;
        }
      }

      answer = cleanAnswerText(answer);

      if (answer.length < minLength) {
        const deterministic = deterministicFallback(question);
        if (deterministic) {
          answer = deterministic;
        }
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
      const finishReason = String(candidates[0]?.finishReason ?? 'unknown');
      return { ok: false, text: '', status: 200, details: `Empty candidate response. finishReason=${finishReason}` };
    }

    return { ok: true, text, status: 200, details: '' };
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    console.error(`Gemini ${args.model} request error`, error);
    return { ok: false, text: '', status: 0, details };
  }
}

function cleanAnswerText(input: string): string {
  return input
    .replace(/\*\*(.*?)\*\*/gs, '$1')
    .replace(/__(.*?)__/gs, '$1')
    .replace(/^#{1,6}\s+/gm, '')
    .replace(/`{1,3}/g, '')
    .replace(/^\s*\*\s+/gm, '- ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function minimumUsefulLength(question: string): number {
  const q = question.toLowerCase().trim();
  if (/^(kailan|anong petsa|anong taon|saan)\b/.test(q)) return 180;
  if (/^(sino si|sino ang)\b/.test(q) && q.length < 65) return 260;
  return 420;
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

  if (q.includes('mactan') || q.includes('lapulapu') || q.includes('magellan')) {
    return `Paksa: Labanan sa Mactan.
- Naganap ang labanan noong Abril 27, 1521 sa Mactan.
- Ang puwersa ni Lapulapu ay nakipaglaban sa pangkat ni Ferdinand Magellan. Napatay si Magellan sa labanan.
- Ang pangunahing salaysay ng pangyayari ay mula kay Antonio Pigafetta, isang kasapi ng ekspedisyon ni Magellan.
- Iwasang ilarawan ito nang sobrang simple bilang isang modernong pambansang digmaan; noong 1521, hindi pa umiiral ang modernong bansang Pilipinas sa kasalukuyang kahulugan.
- Mahalaga ang pangyayari bilang isang malinaw na halimbawa ng lokal na pagtutol sa panghihimasok at kapangyarihang dayuhan.
Sanggunian: Antonio Pigafetta, salaysay ng paglalayag ni Magellan; National Historical Commission of the Philippines (NHCP).`;
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

  if (q.includes('mactan') || q.includes('lapulapu') || q.includes('magellan')) {
    return `Ang Labanan sa Mactan ay naganap noong Abril 27, 1521 sa isla ng Mactan. Nakipaglaban ang mga mandirigma ni Lapulapu sa pangkat ni Ferdinand Magellan, na dumating bilang bahagi ng ekspedisyong Europeo na naglalayag sa kapuluan. Sa labanan, napatay si Magellan at umatras ang kanyang mga kasama.

Mahalagang tandaan na hindi pa umiiral noon ang Pilipinas bilang isang modernong bansang-estado. Kaya mas maingat na ilarawan ang Mactan bilang lokal na pagtutol ni Lapulapu at ng kanyang pamayanan sa dayuhang panghihimasok, kaysa sabihing isa na itong pambansang digmaan para sa buong Pilipinas.

Mahalaga ang Labanan sa Mactan dahil naging isa ito sa pinakatanyag na halimbawa ng paglaban ng isang lokal na pinuno sa puwersang dayuhan noong unang bahagi ng ika-16 na siglo. Ang isa sa pinakamahalagang primaryang salaysay tungkol dito ay isinulat ni Antonio Pigafetta, na kasama sa ekspedisyon ni Magellan.

📚 Sanggunian / Maaaring Basahin
- Antonio Pigafetta, salaysay ng paglalayag ni Magellan
- National Historical Commission of the Philippines (NHCP)`;
  }

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
