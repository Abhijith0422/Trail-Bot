## 2.0.1
* Updated `README.md` to clarify that `trail_ai` supports any online or offline model through pluggable engine interfaces
* Documented that Gemini and `flutter_gemma` are the default engines, not the only supported providers
* Updated the package description in `pubspec.yaml` to reflect generic online/offline model support

## 2.0.0
* Added pluggable online and offline engine support through `onlineEngineBuilder` and `offlineEngineBuilder`
* Added developer-controlled agent profiles with `TrailAiAgentDefinition` and `activeAgentId`
* Added generic online configuration fields while keeping Gemini compatibility for existing apps
* Updated README and package description for pub.dev publishing
* Fixed publish validation issues reported by `flutter pub publish --dry-run`



## 1.0.1
*Updated description in pubspec.yaml

## 1.0.0

* Initial stable release with full null safety support
* Dual AI model support: Google Gemini (online) and Gemma (offline)
* Connectivity-aware automatic model switching
* Real-time streaming responses
* Automatic offline model download and management
* Error handling and fallback mechanisms

## 0.0.1

* Initial pre-release version

