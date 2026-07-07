# trail_ai

`trail_ai` is a reusable Flutter package for building AI chat experiences that work with both cloud and on-device models through one agent API.

Out of the box, it ships with:

- A default online engine powered by Google Gemini
- A default offline engine powered by `flutter_gemma`

It also supports any online or offline model provider you want to use, as long as you plug it in through the package engine interfaces:

- `TrailAiOnlineEngine` for cloud or API-based models
- `TrailAiOfflineEngine` for local or on-device models

That means you can keep the same app-side API while swapping in:

- Online models like Gemini, OpenAI-compatible endpoints, Claude, Groq, or your own backend
- Offline models exposed through your preferred local runtime

## Features

- One agent API for both online and offline chat
- Pluggable online and offline model engines
- Default Gemini online support
- Default `flutter_gemma` offline support
- Developer-defined agent profiles with per-agent model settings
- Connectivity-aware online/offline switching
- Optional fallback to offline when online requests fail
- Streaming and non-streaming responses
- Offline model download progress reporting

## What "any model" means

`trail_ai` is not limited to Gemini and Gemma.

If you want to use a different provider:

- For online models, pass `onlineEngineBuilder`
- For offline models, pass `offlineEngineBuilder`

The package handles agent orchestration, execution mode, prompt/context composition, connectivity awareness, and response streaming. Your custom engine only needs to implement how a specific model is initialized and how it returns streamed text.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  trail_ai:
```

Then run:

```bash
flutter pub get
```

## Quick Start

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

## Default Behavior

Without custom builders:

- Online requests use the built-in Gemini engine
- Offline requests use the built-in `flutter_gemma` engine
- `initialize()` can preload the offline model
- In `auto` mode, the package prefers online when connectivity is available
- If online fails and fallback is enabled, it can switch to offline automatically

## Use Any Online Model

To use a provider other than Gemini, implement `TrailAiOnlineEngine` and pass `onlineEngineBuilder`.

```dart
class MyOnlineEngine implements TrailAiOnlineEngine {
  @override
  Future<void> initialize({
    required TrailAiConfig config,
    required TrailAiAgentDefinition agent,
  }) async {
    // Initialize your provider here.
  }

  @override
  Stream<TrailAiResponseChunk> askStream(String prompt) async* {
    // Stream tokens or chunks from your online model here.
    yield const TrailAiResponseChunk(
      text: 'Hello from a custom online model.',
      source: TrailAiSource.online,
    );
  }

  @override
  Future<void> dispose() async {}
}

final agent = TrailAiAgent(
  config: TrailAiConfig(
    onlineApiKey: 'YOUR_API_KEY',
    onlineModel: 'your-online-model',
    onlineEngineBuilder: (config, agent) => MyOnlineEngine(),
  ),
);
```

You can use `onlineApiKey` and `onlineModel` as generic config fields for your custom provider. The older `geminiApiKey` and `geminiModel` fields still work for backwards compatibility with the default Gemini engine.

## Use Any Offline Model

To use a different local runtime or model format, implement `TrailAiOfflineEngine` and pass `offlineEngineBuilder`.

```dart
class MyOfflineEngine implements TrailAiOfflineEngine {
  @override
  Future<void> initialize({
    required TrailAiConfig config,
    required TrailAiAgentDefinition agent,
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.3, 'Preparing custom offline model...');
    onProgress?.call(1.0, 'Offline model ready');
  }

  @override
  Stream<TrailAiResponseChunk> askStream(String prompt) async* {
    yield const TrailAiResponseChunk(
      text: 'Hello from a custom offline model.',
      source: TrailAiSource.offline,
    );
  }

  @override
  Future<void> dispose() async {}
}

final agent = TrailAiAgent(
  config: TrailAiConfig(
    offlineModelUrl: 'https://example.com/model.task',
    offlineEngineBuilder: (config, agent) => MyOfflineEngine(),
  ),
);
```

This lets you connect `trail_ai` to whatever offline stack your app needs, while keeping the same `ask()` and `askStream()` API.

## Developer-Controlled Agents

The package does not expose any agent picker UI to the app user.

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

## Execution Modes

Each agent can define how it should run:

- `TrailAiExecutionMode.auto`: use online when connected, otherwise offline
- `TrailAiExecutionMode.onlineOnly`: always use the online engine
- `TrailAiExecutionMode.offlineOnly`: always use the offline engine

## Behavior Context

You can provide context in two ways:

- Global context with `TrailAiConfig.agentContext`
- Per-request context with `ask(..., context: '...')`

Per-request context overrides the agent's default context for that call.

## API Overview

- `TrailAiConfig`: global package configuration
- `TrailAiAgentDefinition`: per-agent model and behavior settings
- `TrailAiAgent.initialize()`: starts the active engine setup and connectivity tracking
- `TrailAiAgent.ask()`: returns a full response
- `TrailAiAgent.askStream()`: streams response chunks
- `TrailAiAgent.setActiveAgent()`: switches the active developer-defined agent
- `onlineStatusStream`: emits online/offline status changes
- `downloadProgressStream`: emits offline model download state and progress

## Notes

- The default online engine requires a Gemini-compatible setup through `geminiApiKey` or `onlineApiKey`
- The default offline engine uses `flutter_gemma` and downloads the configured model from `offlineModelUrl`
- Custom engines are the path for supporting other online or offline model providers
- Offline responses require the local model to be ready before use

## Example

See the sample app in [example/lib/main.dart](/C:/Users/abhij/Desktop/Trail%20Bot/example/lib/main.dart) for a simple chat UI using `TrailAiAgent`.
