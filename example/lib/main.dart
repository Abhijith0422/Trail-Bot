import 'package:flutter/material.dart';
import 'package:trail_ai/trail_ai.dart';

void main() {
  runApp(const TrailAiExampleApp());
}

class TrailAiExampleApp extends StatelessWidget {
  const TrailAiExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trail AI Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // TODO: Replace with your actual Gemini API Key
  static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY';

  late final TrailAiAgent _agent;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isInitializing = true;
  bool _isGenerating = false;
  String _initializationStatus = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeAgent();
  }

  Future<void> _initializeAgent() async {
    // Create configuration
    const config = TrailAiConfig(
      geminiApiKey: _geminiApiKey,
      agentContext: 'You are a helpful travel assistant.',
      // Optional: configure offline model settings
      fallbackToOfflineOnOnlineFailure: true,
    );

    _agent = TrailAiAgent(config: config);

    // Listen to download progress for offline model
    _agent.downloadProgressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _initializationStatus =
              '${progress.status} ${(progress.progress * 100).toStringAsFixed(1)}%';
        });
      }
    });

    try {
      await _agent.initialize();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializationStatus = 'Error initializing: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _agent.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isGenerating = true;
    });
    _scrollToBottom();

    try {
      // Add a placeholder for the bot response
      setState(() {
        _messages.add(const ChatMessage(text: '', isUser: false));
      });

      // Use askStream for real-time response
      final stream = _agent.askStream(text);
      String fullResponse = '';

      await for (final chunk in stream) {
        fullResponse += chunk.text;
        if (mounted) {
          setState(() {
            // Update the last message with accumulating text
            _messages.last = ChatMessage(
              text: fullResponse,
              isUser: false,
              source: chunk.source,
            );
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.last = ChatMessage(
            text: 'Error: $e',
            isUser: false,
            isError: true,
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trail AI Chat'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          StreamBuilder<bool>(
            stream: _agent.onlineStatusStream,
            initialData: true,
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? false;
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: isOnline ? Colors.green : Colors.red,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isInitializing)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.amber[100],
              width: double.infinity,
              child: Text(
                _initializationStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _ChatBubble(message: message);
              },
            ),
          ),
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask something...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isGenerating && !_isInitializing,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed:
                      (_isGenerating || _isInitializing) ? null : _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final TrailAiSource? source;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.source,
  });
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final align =
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color =
        message.isUser
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.secondaryContainer;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: message.isError ? Colors.red[100] : color,
            borderRadius: BorderRadius.circular(12.0),
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: message.isError ? Colors.red : Colors.black87,
                ),
              ),
              if (!message.isUser && message.source != null) ...[
                const SizedBox(height: 4),
                Text(
                  message.source == TrailAiSource.online ? 'Online' : 'Offline',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.black54,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
