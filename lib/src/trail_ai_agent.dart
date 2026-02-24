import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'trail_ai_models.dart';

class TrailAiAgent {
  TrailAiAgent({required this.config});

  final TrailAiConfig config;

  late final GenerativeModel _geminiModel;
  late final ChatSession _geminiChat;

  dynamic _gemmaModel;
  dynamic _gemmaChat;

  bool _isInitialized = false;
  bool _isOnline = true;
  bool _isDownloading = false;
  bool _isLocalModelLoaded = false;
  double _downloadProgress = 0;
  String _downloadStatus = '';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final StreamController<bool> _onlineStatusController =
      StreamController<bool>.broadcast();
  final StreamController<TrailAiDownloadProgress> _downloadController =
      StreamController<TrailAiDownloadProgress>.broadcast();

  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;
  bool get isDownloading => _isDownloading;
  bool get isLocalModelLoaded => _isLocalModelLoaded;
  double get downloadProgress => _downloadProgress;
  String get downloadStatus => _downloadStatus;

  Stream<bool> get onlineStatusStream => _onlineStatusController.stream;
  Stream<TrailAiDownloadProgress> get downloadProgressStream =>
      _downloadController.stream;

  Future<void> initialize({bool preloadOfflineModel = true}) async {
    if (_isInitialized) return;

    _geminiModel = GenerativeModel(
      model: config.geminiModel,
      apiKey: config.geminiApiKey,
    );
    _geminiChat = _geminiModel.startChat();

    await _checkConnectivity();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final online = !results.contains(ConnectivityResult.none);
      if (_isOnline != online) {
        _isOnline = online;
        _onlineStatusController.add(_isOnline);
      }
    });

    _isInitialized = true;

    if (preloadOfflineModel) {
      unawaited(preloadOfflineModelIfNeeded());
    }
  }

  Future<void> preloadOfflineModelIfNeeded() async {
    if (_isDownloading || _isLocalModelLoaded) return;

    _isDownloading = true;
    _downloadProgress = 0;
    _downloadStatus = 'Preparing offline AI model...';
    _emitDownloadState();

    try {
      await FlutterGemma.initialize(
        maxDownloadRetries: config.maxDownloadRetries,
      );

      await FlutterGemma.installModel(
        modelType: ModelType.general,
      ).fromNetwork(config.offlineModelUrl).withProgress((progress) {
        var pct = 0;
        try {
          final dynamic anyProgress = progress;
          final dynamic percentage = anyProgress.percentage;
          if (percentage is num) {
            pct = percentage.toInt();
          }
        } catch (_) {}

        _downloadProgress = pct / 100.0;
        _downloadStatus = 'Downloading offline model... $pct%';
        _emitDownloadState();
      }).install();

      _gemmaModel = await FlutterGemma.getActiveModel(
        maxTokens: config.maxLocalTokens,
      );
      _gemmaChat = await _gemmaModel.createChat();
      _isLocalModelLoaded = true;
      _downloadStatus = '';
    } catch (_) {
      _downloadStatus = 'Offline model unavailable: online mode will be used.';
    } finally {
      _isDownloading = false;
      _emitDownloadState();
    }
  }

  Future<TrailAiResult> ask(
    String question, {
    String? context,
    bool? forceOnline,
  }) async {
    final buffer = StringBuffer();
    TrailAiSource? source;

    await for (final chunk in askStream(
      question,
      context: context,
      forceOnline: forceOnline,
    )) {
      source ??= chunk.source;
      buffer.write(chunk.text);
    }

    if (source == null) {
      throw const TrailAiException('No response generated.');
    }

    return TrailAiResult(text: buffer.toString(), source: source);
  }

  Stream<TrailAiResponseChunk> askStream(
    String question, {
    String? context,
    bool? forceOnline,
  }) async* {
    _ensureInitialized();

    final prompt = _buildPrompt(question: question, context: context);
    final shouldUseOnline = forceOnline ?? _isOnline;

    if (shouldUseOnline) {
      try {
        final stream = _geminiChat.sendMessageStream(Content.text(prompt));
        await for (final chunk in stream) {
          final text = chunk.text;
          if (text != null && text.isNotEmpty) {
            yield TrailAiResponseChunk(
              text: text,
              source: TrailAiSource.online,
            );
          }
        }
        return;
      } catch (_) {
        if (!(config.fallbackToOfflineOnOnlineFailure && _isLocalModelLoaded)) {
          rethrow;
        }
      }
    }

    if (!_isLocalModelLoaded || _gemmaChat == null) {
      throw TrailAiException(
        _isDownloading
            ? 'Offline model is still downloading ($_downloadStatus).'
            : 'Offline model is not ready yet.',
      );
    }

    await _gemmaChat.addQueryChunk(Message.text(text: prompt, isUser: true));
    await for (final response in _gemmaChat.generateChatResponseAsync()) {
      if (response is TextResponse && response.token.isNotEmpty) {
        yield TrailAiResponseChunk(
          text: response.token,
          source: TrailAiSource.offline,
        );
      }
    }
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _onlineStatusController.close();
    await _downloadController.close();

    try {
      _gemmaChat?.close();
    } catch (_) {}

    try {
      _gemmaModel?.close();
    } catch (_) {}
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    _onlineStatusController.add(_isOnline);
  }

  void _emitDownloadState() {
    _downloadController.add(
      TrailAiDownloadProgress(
        isDownloading: _isDownloading,
        progress: _downloadProgress,
        status: _downloadStatus,
      ),
    );
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw const TrailAiException(
        'TrailAiAgent is not initialized. Call initialize() first.',
      );
    }
  }

  String _buildPrompt({required String question, String? context}) {
    final effectiveContext = context ?? config.agentContext;
    if (effectiveContext == null || effectiveContext.trim().isEmpty) {
      return question;
    }

    return 'Behavior context:\n$effectiveContext\n\nUser question:\n$question';
  }
}
