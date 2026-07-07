enum TrailAiSource { online, offline }

enum TrailAiExecutionMode { auto, onlineOnly, offlineOnly }

abstract class TrailAiOnlineEngine {
  Future<void> initialize({
    required TrailAiConfig config,
    required TrailAiAgentDefinition agent,
  });

  Stream<TrailAiResponseChunk> askStream(String prompt);

  Future<void> dispose();
}

abstract class TrailAiOfflineEngine {
  Future<void> initialize({
    required TrailAiConfig config,
    required TrailAiAgentDefinition agent,
    void Function(double progress, String status)? onProgress,
  });

  Stream<TrailAiResponseChunk> askStream(String prompt);

  Future<void> dispose();
}

typedef TrailAiOnlineEngineBuilder = TrailAiOnlineEngine Function(
  TrailAiConfig config,
  TrailAiAgentDefinition agent,
);

typedef TrailAiOfflineEngineBuilder = TrailAiOfflineEngine Function(
  TrailAiConfig config,
  TrailAiAgentDefinition agent,
);

class TrailAiAgentDefinition {
  const TrailAiAgentDefinition({
    required this.id,
    this.label,
    this.agentContext,
    this.onlineModel,
    this.geminiModel,
    this.offlineModelUrl,
    this.maxLocalTokens,
    this.maxDownloadRetries,
    this.fallbackToOfflineOnOnlineFailure,
    this.executionMode = TrailAiExecutionMode.auto,
  });

  final String id;
  final String? label;
  final String? agentContext;
  final String? onlineModel;
  final String? geminiModel;
  final String? offlineModelUrl;
  final int? maxLocalTokens;
  final int? maxDownloadRetries;
  final bool? fallbackToOfflineOnOnlineFailure;
  final TrailAiExecutionMode executionMode;
}

class TrailAiConfig {
  const TrailAiConfig({
    this.onlineApiKey,
    this.geminiApiKey,
    this.agentContext,
    this.onlineModel,
    this.geminiModel = 'gemini-2.5-flash',
    this.offlineModelUrl =
        'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    this.maxLocalTokens = 512,
    this.maxDownloadRetries = 3,
    this.fallbackToOfflineOnOnlineFailure = true,
    this.agents = const <TrailAiAgentDefinition>[],
    this.activeAgentId,
    this.onlineEngineBuilder,
    this.offlineEngineBuilder,
  });

  final String? onlineApiKey;
  final String? geminiApiKey;
  final String? agentContext;
  final String? onlineModel;
  final String? geminiModel;
  final String offlineModelUrl;
  final int maxLocalTokens;
  final int maxDownloadRetries;
  final bool fallbackToOfflineOnOnlineFailure;
  final List<TrailAiAgentDefinition> agents;
  final String? activeAgentId;
  final TrailAiOnlineEngineBuilder? onlineEngineBuilder;
  final TrailAiOfflineEngineBuilder? offlineEngineBuilder;
}

class TrailAiDownloadProgress {
  const TrailAiDownloadProgress({
    required this.isDownloading,
    required this.progress,
    required this.status,
  });

  final bool isDownloading;
  final double progress;
  final String status;
}

class TrailAiResponseChunk {
  const TrailAiResponseChunk({required this.text, required this.source});

  final String text;
  final TrailAiSource source;
}

class TrailAiResult {
  const TrailAiResult({required this.text, required this.source});

  final String text;
  final TrailAiSource source;
}

class TrailAiException implements Exception {
  const TrailAiException(this.message);

  final String message;

  @override
  String toString() => 'TrailAiException: $message';
}
