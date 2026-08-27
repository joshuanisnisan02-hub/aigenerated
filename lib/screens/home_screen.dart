import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/chat_message.dart';
import '../services/audio_player_service.dart';
import '../services/lakbay_api.dart';
import '../widgets/animated_lolo.dart';
import '../widgets/conversation_panel.dart';
import '../widgets/mode_selector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _text = TextEditingController();
  final _speech = stt.SpeechToText();
  final _audio = AudioPlayerService();

  static const _chatBaseUrl = String.fromEnvironment(
    'LAKBAY_CHAT_BASE_URL',
    defaultValue: '',
  );

  static const _ttsBaseUrl = String.fromEnvironment(
    'LAKBAY_TTS_BASE_URL',
    defaultValue: '',
  );

  late final LakbayApi _api = LakbayApi(
    chatBaseUrl: _chatBaseUrl,
    ttsBaseUrl: _ttsBaseUrl,
  );

  int _mode = 0;
  bool _busy = false;
  bool _listening = false;
  bool _speaking = false;
  bool _voiceEnabled = true;
  String? _voiceStatus;

  static const _welcome =
      'Mabuhay! Ako si Lakbay Kasaysayan AI, ang iyong gabay sa Kasaysayan ng Pilipinas. Maaari mo akong tanungin tungkol sa mga tao, lugar, pangyayari, at mahahalagang bahagi ng ating kasaysayan. Ano ang gusto mong malaman?';

  final _messages = <ChatMessage>[
    ChatMessage(
      speaker: Speaker.tutor,
      createdAt: DateTime.now(),
      text: _welcome,
    ),
  ];

  static const _suggestions = [
    'Ano ang nangyari sa Labanan sa Mactan?',
    'Bakit mahalaga ang Katipunan?',
    'Sino si Jose Rizal?',
    'Ano ang Martial Law?',
  ];

  @override
  void initState() {
    super.initState();
    _audio.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _speaking = state.playing);
    });
  }

  Future<void> _speak(String text) async {
    if (!_voiceEnabled) return;

    if (!_api.hasNaturalVoice) {
      if (!mounted) return;
      setState(() {
        _voiceStatus =
            'Natural Filipino voice is not configured yet. Run the app with LAKBAY_TTS_BASE_URL pointing to your deployed Supabase Functions URL.';
      });
      return;
    }

    try {
      // Do not show a temporary "Gumagawa ng natural Filipino voice" banner.
      // The character's thinking/speaking states already provide enough feedback.
      if (mounted && _voiceStatus != null) {
        setState(() => _voiceStatus = null);
      }
      final bytes = await _api.synthesize(text);
      await _audio.playBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _voiceStatus = 'Hindi ma-play ang boses. ${e.toString()}');
    }
  }

  Future<void> _send([String? override]) async {
    final question = (override ?? _text.text).trim();
    if (question.isEmpty || _busy) return;

    _text.clear();
    setState(() {
      _busy = true;
      _messages.add(ChatMessage(
        speaker: Speaker.student,
        text: question,
        createdAt: DateTime.now(),
      ));
    });

    try {
      final answer = await _api.ask(question);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          speaker: Speaker.tutor,
          text: answer,
          createdAt: DateTime.now(),
        ));
      });

      await _speak(answer);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          speaker: Speaker.tutor,
          text: 'May problema sa koneksyon. Pakisubukan muli mamaya.',
          createdAt: DateTime.now(),
        ));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final ok = await _speech.initialize();
    if (!ok) return;

    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'fil_PH',
      listenMode: stt.ListenMode.dictation,
      onResult: (result) {
        setState(() => _text.text = result.recognizedWords);
        if (result.finalResult) {
          setState(() => _listening = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _HistoricalBackground()),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  compact: compact,
                  naturalVoiceReady: _api.hasNaturalVoice,
                  voiceEnabled: _voiceEnabled,
                  onVoiceToggle: () async {
                    if (_speaking) await _audio.stop();
                    if (!mounted) return;
                    setState(() => _voiceEnabled = !_voiceEnabled);
                  },
                ),
                if (_voiceStatus != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(compact ? 16 : 26, 0, compact ? 16 : 26, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3D8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x33B07830)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF8B621F)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _voiceStatus!,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF76531F)),
                            ),
                          ),
                          if (!_api.hasNaturalVoice)
                            TextButton.icon(
                              onPressed: () => _speak(_welcome),
                              icon: const Icon(Icons.volume_up_rounded, size: 17),
                              label: const Text('Test voice'),
                            ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(compact ? 12 : 24, 4, compact ? 12 : 24, 18),
                    child: compact ? _mobileLayout() : _desktopLayout(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopLayout() {
    return Row(
      children: [
        Expanded(flex: 5, child: _characterCard()),
        const SizedBox(width: 18),
        Expanded(flex: 7, child: _chatCard()),
      ],
    );
  }

  Widget _mobileLayout() {
    return Column(
      children: [
        SizedBox(height: 260, child: _characterCard(compact: true)),
        const SizedBox(height: 12),
        Expanded(child: _chatCard()),
      ],
    );
  }

  Widget _characterCard({bool compact = false}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF7ECD4), Color(0xFFE8DEC7)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            left: 18,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF173A5E),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'GABAY SA KASAYSAYAN',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Makinig. Magtanong. Tuklasin ang ating kasaysayan.',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF2D2A25)),
                  ),
                ],
              ],
            ),
          ),
          Positioned.fill(
            top: compact ? 20 : 70,
            child: Padding(
              padding: EdgeInsets.fromLTRB(compact ? 82 : 46, 10, compact ? 82 : 46, 0),
              child: AnimatedLolo(isThinking: _busy, isSpeaking: _speaking),
            ),
          ),
          Positioned(
            bottom: 18,
            left: 18,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xE6FFFCF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x26173A5E)),
              ),
              child: Row(
                children: [
                  Icon(
                    _speaking
                        ? Icons.graphic_eq_rounded
                        : (_busy ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded),
                    color: const Color(0xFFB07830),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _speaking ? 'Nagsasalita…' : (_busy ? 'Nag-iisip…' : 'Handang makipagkuwentuhan'),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4B4338)),
                    ),
                  ),
                  if (!_speaking)
                    IconButton(
                      tooltip: 'Pakinggan ang pagbati',
                      onPressed: _api.hasNaturalVoice && _voiceEnabled ? () => _speak(_welcome) : null,
                      icon: const Icon(Icons.volume_up_rounded),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ModeSelector(activeIndex: _mode, onChanged: (v) => setState(() => _mode = v)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _suggestions
                        .map((q) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(label: Text(q), onPressed: () => _send(q)),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ConversationPanel(
              messages: _messages,
              controller: _text,
              onSend: _send,
              onMic: _toggleMic,
              isListening: _listening,
              isBusy: _busy,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.compact,
    required this.naturalVoiceReady,
    required this.voiceEnabled,
    required this.onVoiceToggle,
  });

  final bool compact;
  final bool naturalVoiceReady;
  final bool voiceEnabled;
  final VoidCallback onVoiceToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 26, 14, compact ? 16 : 26, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF173A5E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history_edu_rounded, color: Color(0xFFF4D28D)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lakbay Kasaysayan AI',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF173A5E)),
                ),
                if (!compact)
                  const Text(
                    'AI Filipino History Tutor',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF7B756C)),
                  ),
              ],
            ),
          ),
          Tooltip(
            message: naturalVoiceReady
                ? (voiceEnabled ? 'Natural Filipino voice is enabled' : 'Natural Filipino voice is muted')
                : 'Natural Filipino voice backend is not configured',
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onVoiceToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: naturalVoiceReady ? const Color(0xFFEAF2E8) : const Color(0xFFF2E6CE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(
                      !voiceEnabled
                          ? Icons.volume_off_outlined
                          : (naturalVoiceReady ? Icons.record_voice_over_rounded : Icons.volume_up_outlined),
                      size: 17,
                      color: naturalVoiceReady ? const Color(0xFF3F6847) : const Color(0xFF7E5B28),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      naturalVoiceReady ? 'Natural Filipino' : 'Voice setup',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: naturalVoiceReady ? const Color(0xFF3F6847) : const Color(0xFF7E5B28),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoricalBackground extends StatelessWidget {
  const _HistoricalBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HistoricalBackgroundPainter());
  }
}

class _HistoricalBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFF4EDDE);
    canvas.drawRect(Offset.zero & size, bg);

    final line = Paint()
      ..color = const Color(0x0F173A5E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double y = 60; y < size.height; y += 90) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x < size.width; x += 120) {
        path.quadraticBezierTo(x + 60, y - 12, x + 120, y);
      }
      canvas.drawPath(path, line);
    }

    final glow = Paint()..color = const Color(0x18B88A44);
    canvas.drawCircle(Offset(size.width * .12, size.height * .18), 180, glow);
    canvas.drawCircle(Offset(size.width * .92, size.height * .82), 240, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
