enum Speaker { student, tutor }

class ChatMessage {
  final Speaker speaker;
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.speaker,
    required this.text,
    required this.createdAt,
  });
}
