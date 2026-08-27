import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/audio_player_service.dart';
import '../services/lakbay_api.dart';

class ConversationPanel extends StatefulWidget {
  const ConversationPanel({
    super.key,
    required this.messages,
    required this.controller,
    required this.onSend,
    required this.onMic,
    required this.isListening,
    required this.isBusy,
  });

  final List<ChatMessage> messages;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMic;
  final bool isListening;
  final bool isBusy;

  @override
  State<ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<ConversationPanel> {
  static const _ttsBaseUrl = String.fromEnvironment(
    'LAKBAY_TTS_BASE_URL',
    defaultValue: '',
  );

  late final LakbayApi _api = LakbayApi(
    chatBaseUrl: '',
    ttsBaseUrl: _ttsBaseUrl,
  );
  final AudioPlayerService _audio = AudioPlayerService();

  bool _replaying = false;
  int? _activeIndex;

  Future<void> _speak(int index, String text) async {
    if (_ttsBaseUrl.isEmpty || _replaying) return;

    setState(() {
      _replaying = true;
      _activeIndex = index;
    });

    try {
      await _audio.stop();
      final bytes = await _api.synthesize(text);
      await _audio.playBytes(bytes);
    } catch (_) {
      // The main screen already exposes voice/backend errors. Keep replay taps
      // unobtrusive and avoid adding another banner inside the conversation.
    } finally {
      if (mounted) {
        setState(() {
          _replaying = false;
          _activeIndex = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            itemCount: widget.messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final m = widget.messages[i];
              final tutor = m.speaker == Speaker.tutor;
              final replayingThis = _replaying && _activeIndex == i;

              final bubble = Container(
                decoration: BoxDecoration(
                  color: tutor ? const Color(0xFFF4EBD8) : const Color(0xFF173A5E),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(tutor ? 6 : 20),
                    bottomRight: Radius.circular(tutor ? 20 : 6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tutor ? 'Lakbay Kasaysayan AI' : 'Estudyante',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: tutor ? const Color(0xFF7E5B28) : const Color(0xFFBFD6EE),
                              ),
                            ),
                          ),
                          if (tutor)
                            Icon(
                              replayingThis ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                              size: 17,
                              color: const Color(0xFF9B7438),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.text,
                        style: TextStyle(
                          height: 1.55,
                          fontSize: 15.5,
                          color: tutor ? const Color(0xFF25221D) : Colors.white,
                        ),
                      ),
                      if (tutor) ...[
                        const SizedBox(height: 8),
                        Text(
                          replayingThis ? 'Pinapakinggan…' : 'I-click para pakinggan',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9A835F),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );

              return Align(
                alignment: tutor ? Alignment.centerLeft : Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: tutor
                      ? MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Semantics(
                            button: true,
                            label: 'Pakinggan ang sagot ni Lakbay',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _replaying ? null : () => _speak(i, m.text),
                              child: bubble,
                            ),
                          ),
                        )
                      : bubble,
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFCF5),
            border: Border(top: BorderSide(color: Color(0x1F173A5E))),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Magsalita',
                  onPressed: widget.isBusy ? null : widget.onMic,
                  icon: Icon(widget.isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => widget.onSend(),
                    decoration: InputDecoration(
                      hintText: 'Magtanong tungkol sa Kasaysayan ng Pilipinas…',
                      filled: true,
                      fillColor: const Color(0xFFF7F3EA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'Ipadala',
                  onPressed: widget.isBusy ? null : widget.onSend,
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF173A5E)),
                  icon: widget.isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
