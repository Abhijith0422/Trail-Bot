import 'package:flutter_test/flutter_test.dart';

import 'package:trail_ai/trail_ai.dart';

void main() {
  test('TrailAiConfig uses expected defaults', () {
    const config = TrailAiConfig(geminiApiKey: 'test-key');

    expect(config.geminiApiKey, 'test-key');
    expect(config.geminiModel, 'gemini-2.5-flash');
    expect(config.maxLocalTokens, 512);
    expect(config.maxDownloadRetries, 3);
    expect(config.fallbackToOfflineOnOnlineFailure, isTrue);
  });

  test('TrailAiConfig supports a generic online model override', () {
    const config = TrailAiConfig(onlineModel: 'gpt-4o-mini');

    expect(config.onlineModel, 'gpt-4o-mini');
    expect(config.geminiModel, 'gemini-2.5-flash');
  });

  test('TrailAiConfig can register developer-selected agents', () {
    const config = TrailAiConfig(
      geminiApiKey: 'test-key',
      activeAgentId: 'offline-agent',
      agents: [
        TrailAiAgentDefinition(
          id: 'online-agent',
          label: 'Online',
          executionMode: TrailAiExecutionMode.onlineOnly,
        ),
        TrailAiAgentDefinition(
          id: 'offline-agent',
          label: 'Offline',
          executionMode: TrailAiExecutionMode.offlineOnly,
        ),
      ],
    );

    expect(config.activeAgentId, 'offline-agent');
    expect(config.agents, hasLength(2));
    expect(config.agents.first.id, 'online-agent');
    expect(config.agents.last.executionMode, TrailAiExecutionMode.offlineOnly);
  });

  test('TrailAiException has readable message', () {
    const exception = TrailAiException('something failed');
    expect(exception.toString(), 'TrailAiException: something failed');
  });

  test('TrailAiResult stores response data', () {
    const result = TrailAiResult(text: 'hello', source: TrailAiSource.online);

    expect(result.text, 'hello');
    expect(result.source, TrailAiSource.online);
  });
}
