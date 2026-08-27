# Lakbay Kasaysayan AI — Flutter Edition

This is the non-HTML rebuild of **Lakbay Kasaysayan AI** using **Flutter (Dart)**.
It is designed for Windows, Android, iOS, macOS, and Flutter Web from one codebase.

## Why Flutter

- Smoother character motion than a plain HTML prototype.
- One responsive UI for desktop/tablet/mobile.
- Better control of animation, microphone input, audio playback, and future Rive/Live2D integration.
- Can be packaged as a real Windows/Android application instead of only a webpage.

## Character

The project includes the older Filipino history-guide mascot in:

`assets/images/lakbay_lolo.svg`

The current Flutter character layer includes subtle breathing, sway, blinking, thinking state, and a speaking mouth overlay.
For **production-quality facial rigging**, replace the vector layer with a Rive or Live2D character while keeping the same `AnimatedLolo` state inputs (`isThinking`, `isSpeaking`).

Recommended final animation states:

- idle/breathing
- blink
- smile/wave
- listening
- thinking
- speaking
- serious
- excited/trivia
- respectful/somber

For high-quality lip synchronization, the TTS backend should return viseme/phoneme timing, and the Rive/Live2D mouth parameters should follow those timings instead of simply toggling a mouth animation.

## Natural Filipino voice

Do **not** use the browser `speechSynthesis` voice for the final app. That is the main reason many prototypes sound robotic.

The planned production voice is a Filipino male neural/HD voice, configured server-side so credentials are never exposed in the Flutter app.

The prosody should be warm, fluent in Filipino, and slightly conversational. The user's reference audio is used only as a **speaking-style/accent reference**; it does not clone the speaker's identity.

### Backend configuration

Set the deployed backend base URL in `LakbayApi(baseUrl: ...)`, for example:

`https://YOUR_PROJECT.supabase.co/functions/v1`

Keep all AI and speech-provider keys in the backend or Supabase Edge Function secrets.

## Run the Flutter project

Install Flutter, then from this folder:

```bash
flutter create .
flutter pub get
flutter run -d windows
```

For Android:

```bash
flutter run -d android
```

For web:

```bash
flutter run -d chrome
```

## Important note about “not sounding like AI”

Dynamic answers must still be synthesized by a TTS engine unless you pre-record every possible line with a human voice actor. The goal is therefore a **human-like, native Filipino delivery that does not sound robotic**, rather than claiming the generated voice is literally non-AI.

For the best classroom result, use a native Filipino neural/HD voice, tune pauses and pacing, and add viseme-driven lip sync. A hybrid option is also strong: record the fixed welcome/transition lines with a real Filipino voice actor, then use neural TTS only for dynamic answers.
