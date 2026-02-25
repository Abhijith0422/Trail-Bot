# Trail AI Example App

A simple Flutter example application demonstrating how to use the `trail_ai` package.

## Features

- Initializes the `TrailAiAgent` with configuration.
- Supports both online (Gemini) and offline (Gemma) model usage.
- Shows real-time connectivity status.
- Displays download progress when fetching the offline model.
- Simple chat interface to interact with the AI.

## Getting Started

1.  **Get an API Key**: obtain a Gemini API key from Google AI Studio.
2.  **Configure**: Open `lib/main.dart` and replace `YOUR_GEMINI_API_KEY` with your actual key.
3.  **Run**:
    ```bash
    flutter pub get
    flutter run
    ```
