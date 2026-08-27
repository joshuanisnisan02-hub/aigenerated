# Production setup checklist

- [ ] Install Flutter 3.x on the development PC.
- [ ] Run `flutter pub get`.
- [ ] Create Supabase project or use the existing project.
- [ ] Deploy `lakbay-tts` Edge Function.
- [ ] Add Azure Speech key/region as Supabase secrets.
- [ ] Set `LakbayApi(baseUrl: ...)` to the deployed functions URL.
- [ ] Connect `lakbay-chat` to the chosen LLM plus Philippine-history RAG sources.
- [ ] Replace simple image animation with a rigged Rive/Live2D character for final production quality.
- [ ] Add viseme timing to drive mouth shapes precisely.
- [ ] Test Tagalog pronunciation of names such as Jose Rizal, Andres Bonifacio, Gomburza, Lapulapu, and Emilio Aguinaldo.
- [ ] Test on Windows and Android before classroom deployment.
