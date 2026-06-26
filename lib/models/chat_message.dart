class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.fromUser,
    this.route,
  });

  final String text;
  final bool fromUser;
  final String? route;
}

class ChatAnswer {
  const ChatAnswer({required this.route, required this.answer});

  final String route;
  final String answer;

  factory ChatAnswer.fromJson(Map<String, dynamic> json) {
    return ChatAnswer(
      route: json['route'] as String? ?? 'GENERAL',
      answer: json['answer'] as String? ?? '',
    );
  }
}
