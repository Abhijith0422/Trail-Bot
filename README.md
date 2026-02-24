# trail_ai

`trail_ai` is a reusable Flutter package that gives you one agent API for:

- Online chat with Gemini
- Offline chat with a local model via `flutter_gemma`
- Auto online/offline switching from network connectivity
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

- `TrailAiConfig`: setup key, model names/urls, default behavior context
- `TrailAiAgent.initialize()`: starts Gemini, connectivity listener, optional offline preload
- `TrailAiAgent.ask()` / `askStream()`: send questions with optional per-call context override
- `onlineStatusStream`: emits online/offline state changes
- `downloadProgressStream`: emits local model download state/progress

## Behavior context

You can provide context in two ways:

- Global context in `TrailAiConfig.agentContext`
- Request-level context in `ask(..., context: '...')`

Request-level context overrides global context for that question.

## Notes

- Offline responses require the local model to be downloaded and ready.
- If online fails and `fallbackToOfflineOnOnlineFailure` is `true`, the agent tries local model automatically.
