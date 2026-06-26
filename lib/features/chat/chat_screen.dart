import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/services.dart';
import '../../models/chat_message.dart';
import '../../shared/widgets/async_state.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.authController});

  final AuthController authController;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final scrollController = ScrollController();
  final messages = <ChatMessage>[];
  bool sending = false;
  bool loadingMemory = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadMemory();
  }

  @override
  void dispose() {
    input.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Assistant',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: sending ? null : _reset,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Reset'),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: loadingMemory
              ? const LoadingView(message: 'Loading chat memory')
              : messages.isEmpty
              ? const EmptyView(
                  title: 'Ask about operations',
                  subtitle:
                      'Questions about tasks, workers, reviews, or cleaning operations will appear here.',
                  icon: Icons.chat_bubble_outline,
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _ChatBubble(message: messages[index]),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => sending ? null : _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask the cleaning assistant...',
                      prefixIcon: Icon(Icons.auto_awesome_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: sending ? null : _send,
                  child: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadMemory() async {
    setState(() {
      loadingMemory = true;
      error = null;
    });
    try {
      final context = await ChatApi(widget.authController.apiClient).context();
      if (!mounted) return;
      setState(() => _replaceWithMemoryMessages(context.trim()));
    } catch (e) {
      if (!mounted) return;
      setState(() => error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => loadingMemory = false);
    }
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      sending = true;
      error = null;
      messages.add(ChatMessage(text: text, fromUser: true));
      input.clear();
    });
    _scrollToEnd();
    try {
      final answer = await ChatApi(widget.authController.apiClient).ask(text);
      setState(() {
        messages.add(
          ChatMessage(
            text: answer.answer.isEmpty ? 'No answer returned.' : answer.answer,
            fromUser: false,
            route: answer.route,
          ),
        );
      });
      await _loadMemory();
      _scrollToEnd();
    } catch (e) {
      setState(() => error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await ChatApi(widget.authController.apiClient).resetContext();
      setState(() {
        messages.clear();
      });
    } catch (e) {
      setState(() => error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _replaceWithMemoryMessages(String context) {
    messages.removeWhere((message) => message.route == 'MEMORY');
    if (context.isEmpty) return;
    messages.insertAll(0, _parseMemoryContext(context));
  }

  List<ChatMessage> _parseMemoryContext(String context) {
    final parsed = <ChatMessage>[];
    final pattern = RegExp(
      r'([^\n{}][^\n]*)\n\{\s*"answer"\s*:\s*"((?:\\.|[^"\\])*)"\s*\}',
      multiLine: true,
      dotAll: true,
    );
    for (final match in pattern.allMatches(context)) {
      final question = match.group(1)?.trim();
      final answer = match.group(2)?.replaceAll(r'\"', '"').trim();
      if (question != null && question.isNotEmpty) {
        parsed.add(
          ChatMessage(text: question, fromUser: true, route: 'MEMORY'),
        );
      }
      if (answer != null && answer.isNotEmpty) {
        parsed.add(ChatMessage(text: answer, fromUser: false, route: 'MEMORY'));
      }
    }
    if (parsed.isNotEmpty) return parsed;
    return [ChatMessage(text: context, fromUser: false, route: 'MEMORY')];
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('503') || message.contains('not configured')) {
      return 'Chat is not available right now. Try again later or contact your admin.';
    }
    if (message.contains('502') || message.contains('model request failed')) {
      return 'The model request failed. Try again in a moment.';
    }
    return message;
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Card(
          color: message.fromUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(message.text)],
            ),
          ),
        ),
      ),
    );
  }
}
