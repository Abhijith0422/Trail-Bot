# trail_ai

`trail_ai` is a reusable Flutter package that gives you one agent API for:

- Online chat through a pluggable provider interface, with Gemini as the default
- Offline chat through a pluggable local-model interface, with `flutter_gemma` as the default
- Developer-controlled agent profiles with automatic online/offline switching from network connectivity
- Optional fallback to offline when online fails
- Streaming and non-streaming responses

## Quick start

Add dependency:

```yaml
dependencies:
	trail_ai:
```

Create and initialize an agent:

```dart
import 'package:trail_ai/trail_ai.dart';

final agent = TrailAiAgent(
	config: const TrailAiConfig(
		geminiApiKey: 'YOUR_GEMINI_API_KEY',
		agentContext: 'You are a concise travel assistant.',
	),
);

await agent.initialize();
```

Ask a question and get a complete response:

```dart
final result = await agent.ask('Plan a 3-day trip to Jaipur');
print(result.source); // TrailAiSource.online or TrailAiSource.offline
print(result.text);
```

Ask with streaming chunks:

```dart
await for (final chunk in agent.askStream('Best places to visit in Udaipur?')) {
	print(chunk.text);
}
```

Dispose when done:

```dart
await agent.dispose();
```

## API overview

- `TrailAiConfig`: setup key, model names/urls, default behavior context, and provider builders
- `TrailAiAgentDefinition`: define named developer-selected agents with their own models, prompts, and execution mode
- `TrailAiAgent.initialize()`: starts the active online provider, connectivity listener, and optional offline preload
- `TrailAiAgent.ask()` / `askStream()`: send questions with optional per-call context override
- `onlineStatusStream`: emits online/offline state changes
- `downloadProgressStream`: emits local model download state/progress

## Provider switching

The package is built so the developer can swap the online or offline engine without changing the app UI.

By default, the online engine uses Gemini and the offline engine uses `flutter_gemma`. If you want another online provider such as GPT, pass a custom `onlineEngineBuilder`. If you want another offline runtime, pass a custom `offlineEngineBuilder`.

When you use a custom online provider, `onlineApiKey` and `onlineModel` are the generic fields to set. The old `geminiApiKey` and `geminiModel` names still work for backwards compatibility.

## Developer-controlled agents

The package does not expose any agent picker to the app user.

Instead, the developer can register one or more named agents in code and choose the active one before or after initialization:

```dart
final agent = TrailAiAgent(
	config: TrailAiConfig(
		onlineApiKey: 'YOUR_API_KEY',
		onlineModel: 'gpt-4o-mini',
		agents: const [
			TrailAiAgentDefinition(
				id: 'travel-online',
				label: 'Travel Assistant Online',
				onlineModel: 'gpt-4o-mini',
				agentContext: 'You are a concise travel assistant.',
				executionMode: TrailAiExecutionMode.onlineOnly,
			),
			TrailAiAgentDefinition(
				id: 'travel-offline',
				label: 'Travel Assistant Offline',
				offlineModelUrl: 'https://example.com/my-offline-model.task',
				executionMode: TrailAiExecutionMode.offlineOnly,
			),
		],
		activeAgentId: 'travel-online',
	),
);

await agent.initialize();
```

You can switch agents from developer code only:

```dart
await agent.setActiveAgent('travel-offline');
```

## Behavior context

You can provide context in two ways:

- Global context in `TrailAiConfig.agentContext`
- Request-level context in `ask(..., context: '...')`

Request-level context overrides global context for that question.

## Notes

- Offline responses require the local model to be downloaded and ready.
- If online fails and `fallbackToOfflineOnOnlineFailure` is `true`, the agent tries local model automatically.
