enum TrailAiSource { online, offline }

class TrailAiConfig {
  const TrailAiConfig({
    required this.geminiApiKey,
    this.agentContext,
    this.geminiModel = 'gemini-2.5-flash',
    this.offlineModelUrl =
        'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    this.maxLocalTokens = 512,
    this.maxDownloadRetries = 3,
    this.fallbackToOfflineOnOnlineFailure = true,
  });

  final String geminiApiKey;
  final String? agentContext;
  final String geminiModel;
  final String offlineModelUrl;
  final int maxLocalTokens;
  final int maxDownloadRetries;
  final bool fallbackToOfflineOnOnlineFailure;
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
