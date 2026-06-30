import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/colors.dart';
import '../utils/chat_formatter.dart';
import '../services/api_service.dart';

/// Shared chat UI for patient and dentist modes.
class ChatbotScreen extends StatefulWidget {
  final bool dentistMode;
  const ChatbotScreen({super.key, this.dentistMode = false});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _apiService = ApiService();
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _historyLoaded = false;

  String get _welcome => widget.dentistMode
      ? 'Hello Doctor! I am OralVision Clinical Assistant. Ask about treatment protocols, patient triage, prescriptions, or dental procedures.'
      : 'Hello! I am OralVision AI assistant. How can I help you with your dental health today?';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _ensureWelcome();
        return;
      }
      final history = await _supabase
          .from('chatbot_history')
          .select()
          .eq('user_id', user.id)
          .order('sent_at', ascending: true)
          .limit(30);
      if (!mounted) return;
      setState(() {
        _messages = List<Map<String, dynamic>>.from(history);
        _historyLoaded = true;
      });
      if (_messages.isEmpty) _ensureWelcome();
    } catch (_) {
      _ensureWelcome();
    }
  }

  void _ensureWelcome() {
    if (_messages.isEmpty) {
      setState(() {
        _messages.add({'role': 'assistant', 'message': _welcome});
        _historyLoaded = true;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'message': text});
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('chatbot_history').insert({
          'user_id': user.id,
          'role': 'user',
          'message': text,
        });
      }

      final payload = widget.dentistMode ? 'clinical: $text' : text;
      final response = await _apiService.sendChat(
        [{'role': 'user', 'content': payload}],
        user?.id ?? '',
      );

      final botMessage = ChatFormatter.format(
        response['content']?.toString() ??
            'Sorry, I could not process that. Try asking about tooth pain, gums, or appointments.',
      );

      if (user != null) {
        await _supabase.from('chatbot_history').insert({
          'user_id': user.id,
          'role': 'assistant',
          'message': botMessage,
        });
      }

      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'assistant', 'message': botMessage});
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'message': 'Connection issue. The AI server may be waking up — please try again in a few seconds.',
        });
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.dentistMode ? AppColors.dentist : AppColors.primary;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: themeColor,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 16,
              child: Icon(Icons.smart_toy, color: themeColor, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.dentistMode ? 'Clinical Assistant' : 'OralVision AI',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.dentistMode ? 'For dental professionals' : 'Always here to help',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_historyLoaded)
            IconButton(
              tooltip: 'Clear chat',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _messages = [{'role': 'assistant', 'message': _welcome}];
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: isUser ? themeColor : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 16),
                      ),
                      boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.15), blurRadius: 5)],
                    ),
                    child: Text(
                      msg['message'] ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : AppColors.textDark,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  CircularProgressIndicator(strokeWidth: 2, color: themeColor),
                  const SizedBox(width: 10),
                  const Text('AI is typing...', style: TextStyle(color: AppColors.textLight)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: widget.dentistMode
                          ? 'Ask about clinical guidance...'
                          : 'Ask about your dental health...',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dentist-facing chatbot route wrapper.
class DentistChatbotScreen extends StatelessWidget {
  const DentistChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatbotScreen(dentistMode: true);
  }
}
