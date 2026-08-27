import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ConversationPanel extends StatelessWidget {
  const ConversationPanel({
    super.key,
    required this.messages,
    required this.controller,
    required this.onSend,
    required this.onMic,
    required this.onSpeak,
    required this.isListening,
    required this.isBusy,
    required this.isSpeaking,
  });

  final List<ChatMessage> messages;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMic;
  final ValueChanged<String> onSpeak;
  final bool isListening;
  final bool isBusy;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            itemCount: messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final m = messages[i];
              final tutor = m.speaker == Speaker.tutor;

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
                              isSpeaking ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
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
                        const Text(
                          'I-click para pakinggan',
                          style: TextStyle(
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
                              onTap: () => onSpeak(m.text),
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
                  onPressed: isBusy ? null : onMic,
                  icon: Icon(isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
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
                  onPressed: isBusy ? null : onSend,
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF173A5E)),
                  icon: isBusy
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
