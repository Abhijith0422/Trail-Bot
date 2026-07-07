import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'trail_ai_models.dart';

class TrailAiAgent {
  TrailAiAgent({required this.config});

  final TrailAiConfig config;

  final Map<String, TrailAiAgentDefinition> _agentDefinitions = {};

  TrailAiOnlineEngine? _onlineEngine;
  TrailAiOfflineEngine? _offlineEngine;

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

  String get activeAgentId => _activeAgentDefinition?.id ?? 'default';

  List<TrailAiAgentDefinition> get availableAgents =>
      List<TrailAiAgentDefinition>.unmodifiable(_agentDefinitions.values);

  TrailAiAgentDefinition? get activeAgentDefinition => _activeAgentDefinition;

  TrailAiAgentDefinition? _activeAgentDefinition;

  TrailAiAgentDefinition get _defaultDefinition => TrailAiAgentDefinition(
        id: 'default',
        agentContext: config.agentContext,
      onlineModel: config.onlineModel ?? config.geminiModel,
      geminiModel: config.geminiModel,
        offlineModelUrl: config.offlineModelUrl,
        maxLocalTokens: config.maxLocalTokens,
        maxDownloadRetries: config.maxDownloadRetries,
        fallbackToOfflineOnOnlineFailure:
            config.fallbackToOfflineOnOnlineFailure,
      );

  TrailAiAgentDefinition _resolveDefinition(String agentId) {
    final base = _agentDefinitions[agentId];
    if (base == null) {
      throw TrailAiException('Unknown agent "$agentId".');
    }

    return TrailAiAgentDefinition(
      id: base.id,
      label: base.label,
      agentContext: base.agentContext ?? config.agentContext,
      onlineModel:
          base.onlineModel ?? base.geminiModel ?? config.onlineModel ?? config.geminiModel,
      geminiModel: base.geminiModel ?? config.geminiModel,
      offlineModelUrl: base.offlineModelUrl ?? config.offlineModelUrl,
      maxLocalTokens: base.maxLocalTokens ?? config.maxLocalTokens,
      maxDownloadRetries: base.maxDownloadRetries ?? config.maxDownloadRetries,
      fallbackToOfflineOnOnlineFailure:
          base.fallbackToOfflineOnOnlineFailure ??
              config.fallbackToOfflineOnOnlineFailure,
      executionMode: base.executionMode,
    );
  }

  TrailAiAgentDefinition get _currentDefinition =>
      _activeAgentDefinition ?? _defaultDefinition;

  bool get _currentDefinitionAllowsOffline =>
      _currentDefinition.executionMode != TrailAiExecutionMode.onlineOnly;

  String get _currentOnlineApiKey =>
      config.onlineApiKey ?? config.geminiApiKey ?? '';

  bool get _canUseDefaultOnlineEngine =>
      _currentOnlineApiKey.trim().isNotEmpty;

  Future<void> initialize({bool preloadOfflineModel = true}) async {
    if (_isInitialized) return;

    _buildAgentRegistry();
    _activeAgentDefinition = _resolveInitialDefinition();

    if (_currentDefinition.executionMode != TrailAiExecutionMode.offlineOnly) {
      await _initializeOnlineEngine();
    }

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

    if (preloadOfflineModel && _currentDefinitionAllowsOffline) {
      unawaited(preloadOfflineModelIfNeeded());
    }
  }

  Future<void> setActiveAgent(
    String agentId, {
    bool preloadOfflineModel = true,
  }) async {
    _ensureInitialized();

    final resolved = _resolveDefinition(agentId);
    if (_activeAgentDefinition?.id == resolved.id) {
      return;
    }

    await _resetRuntimeState();
    _activeAgentDefinition = resolved;

    if (_currentDefinition.executionMode != TrailAiExecutionMode.offlineOnly) {
      await _initializeOnlineEngine();
    }

    if (preloadOfflineModel && _currentDefinitionAllowsOffline) {
      await preloadOfflineModelIfNeeded();
    }
  }

  Future<void> preloadOfflineModelIfNeeded() async {
    if (_isDownloading || _isLocalModelLoaded) return;

    if (!_currentDefinitionAllowsOffline) return;

    _isDownloading = true;
    _downloadProgress = 0;
    _downloadStatus = 'Preparing offline AI model...';
    _emitDownloadState();

    final effectiveDefinition = _currentDefinition;

    try {
      _offlineEngine ??=
          _buildOfflineEngineForDefinition(effectiveDefinition);

      await _offlineEngine!.initialize(
        config: config,
        agent: effectiveDefinition,
        onProgress: (progress, status) {
          _downloadProgress = progress;
          _downloadStatus = status;
          _emitDownloadState();
        },
      );

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
    final shouldUseOnline = forceOnline ??
        switch (_currentDefinition.executionMode) {
          TrailAiExecutionMode.auto => _isOnline,
          TrailAiExecutionMode.onlineOnly => true,
          TrailAiExecutionMode.offlineOnly => false,
        };

    if (shouldUseOnline) {
      try {
        await _ensureOnlineEngineInitialized();
        await for (final chunk in _onlineEngine!.askStream(prompt)) {
          yield chunk;
        }
        return;
      } catch (_) {
        final fallbackEnabled =
            _currentDefinition.fallbackToOfflineOnOnlineFailure ??
                config.fallbackToOfflineOnOnlineFailure;
        if (!(fallbackEnabled && _isLocalModelLoaded && _currentDefinitionAllowsOffline)) {
          rethrow;
        }
      }
    }

    if (!_isLocalModelLoaded || _offlineEngine == null) {
      throw TrailAiException(
        _isDownloading
            ? 'Offline model is still downloading ($_downloadStatus).'
            : 'Offline model is not ready yet.',
      );
    }

    await _ensureOfflineEngineInitialized();
    await for (final chunk in _offlineEngine!.askStream(prompt)) {
      yield chunk;
    }
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _onlineStatusController.close();
    await _downloadController.close();

    await _resetRuntimeState();

    _isInitialized = false;
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

  void _buildAgentRegistry() {
    _agentDefinitions.clear();

    for (final agent in config.agents) {
      _agentDefinitions[agent.id] = agent;
    }

    if (_agentDefinitions.isEmpty) {
      _agentDefinitions[_defaultDefinition.id] = _defaultDefinition;
    }
  }

  TrailAiAgentDefinition _resolveInitialDefinition() {
    final requestedId = config.activeAgentId;
    if (requestedId != null) {
      return _resolveDefinition(requestedId);
    }

    return _resolveDefinition(_agentDefinitions.keys.first);
  }

  Future<void> _initializeOnlineEngine() async {
    _onlineEngine ??= _buildOnlineEngineForDefinition(_currentDefinition);
    await _onlineEngine!.initialize(
      config: config,
      agent: _currentDefinition,
    );
  }

  Future<void> _ensureOnlineEngineInitialized() async {
    _onlineEngine ??= _buildOnlineEngineForDefinition(_currentDefinition);
  }

  Future<void> _ensureOfflineEngineInitialized() async {
    if (_offlineEngine == null) {
      _offlineEngine = _buildOfflineEngineForDefinition(_currentDefinition);
      await _offlineEngine!.initialize(
        config: config,
        agent: _currentDefinition,
      );
    }
  }

  Future<void> _resetRuntimeState() async {
    try {
      await _onlineEngine?.dispose();
    } catch (_) {}

    try {
      await _offlineEngine?.dispose();
    } catch (_) {}

    _onlineEngine = null;
    _offlineEngine = null;
    _isLocalModelLoaded = false;
    _isDownloading = false;
    _downloadProgress = 0;
    _downloadStatus = '';
  }

  String _buildPrompt({required String question, String? context}) {
    final effectiveContext = context ?? _currentDefinition.agentContext;
    if (effectiveContext == null || effectiveContext.trim().isEmpty) {
      return question;
    }

    return 'Behavior context:\n$effectiveContext\n\nUser question:\n$question';
  }

  TrailAiOnlineEngine _buildOnlineEngineForDefinition(
    TrailAiAgentDefinition definition,
  ) {
    final builder = config.onlineEngineBuilder;
    if (builder != null) {
      return builder(config, definition);
    }

    if (!_canUseDefaultOnlineEngine) {
      throw const TrailAiException(
        'No online API key or online engine builder was provided.',
      );
    }

    return _GeminiOnlineEngine();
  }

  TrailAiOfflineEngine _buildOfflineEngineForDefinition(
    TrailAiAgentDefinition definition,
  ) {
    final builder = config.offlineEngineBuilder;
    if (builder != null) {
      return builder(config, definition);
    }

    return _FlutterGemmaOfflineEngine();
  }
}

class _GeminiOnlineEngine implements TrailAiOnlineEngine {
  GenerativeModel? _model;
  ChatSession? _chat;

  @override
  Future<void> initialize({
    required TrailAiConfig config,
    required TrailAiAgentDefinition agent,
  }) async {
    final apiKey = config.onlineApiKey ?? config.geminiApiKey;
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const TrailAiException(
        'A Gemini API key is required when using the default online engine.',
      );
    }

    final modelName =
      agent.onlineModel ?? agent.geminiModel ?? config.onlineModel ?? config.geminiModel;

    _model = GenerativeModel(
      model: modelName ?? 'gemini-2.5-flash',
      apiKey: apiKey,
    );
    _chat = _model!.startChat();
  }

  @override
  Stream<TrailAiResponseChunk> askStream(String prompt) async* {
    final chat = _chat;
    if (chat == null) {
      throw const TrailAiException('Online engine is not initialized.');
    }

    final stream = chat.sendMessageStream(Content.text(prompt));
    await for (final chunk in stream) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) {
        yield TrailAiResponseChunk(
          text: text,
          source: TrailAiSource.online,
        );
      }
    }
  }

  @override
  Future<void> dispose() async {
    _model = null;
    _chat = null;
  }
}

class _FlutterGemmaOfflineEngine implements TrailAiOfflineEngine {
  dynamic _model;
  dynamic _chat;

  @override
  Future<void> initialize({
    required TrailAiConfig config,
    required TrailAiAgentDefinition agent,
    void Function(double progress, String status)? onProgress,
  }) async {
    await FlutterGemma.initialize(
      maxDownloadRetries: agent.maxDownloadRetries ?? config.maxDownloadRetries,
    );

    await FlutterGemma.installModel(
      modelType: ModelType.general,
    ).fromNetwork(agent.offlineModelUrl ?? config.offlineModelUrl).withProgress((progress) {
      var pct = 0;
      try {
        final dynamic anyProgress = progress;
        final dynamic percentage = anyProgress.percentage;
        if (percentage is num) {
          pct = percentage.toInt();
        }
      } catch (_) {}

      if (onProgress != null) {
        onProgress(pct / 100.0, 'Downloading offline model... $pct%');
      }
    }).install();

    _model = await FlutterGemma.getActiveModel(
      maxTokens: agent.maxLocalTokens ?? config.maxLocalTokens,
    );
    _chat = await _model.createChat();
  }

  @override
  Stream<TrailAiResponseChunk> askStream(String prompt) async* {
    final chat = _chat;
    if (chat == null) {
      throw const TrailAiException('Offline engine is not initialized.');
    }

    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse && response.token.isNotEmpty) {
        yield TrailAiResponseChunk(
          text: response.token,
          source: TrailAiSource.offline,
        );
      }
    }
  }

  @override
  Future<void> dispose() async {
    try {
      _chat?.close();
    } catch (_) {}

    try {
      _model?.close();
    } catch (_) {}

    _chat = null;
    _model = null;
  }
}
