import 'dart:io';

/// Configuration for the AI assistant integration.
///
/// The API key is stored in the backend's .env file, not in Flutter.
/// The Flutter app connects to the backend proxy which holds the key.
/// For local development without a backend, the app works in demo mode
/// using a local rule-based assistant (existing behavior).
///
/// All models below are verified free-tier models on OpenRouter ($0 input / $0 output).
/// No paid models are configured. Never automatically switch to a paid model.
class AIConfig {
  /// Base URL for the backend proxy (used by Flutter to reach the backend)
  static const String baseUrl = 'http://localhost:3001';

  /// Default model to use (free tier model on OpenRouter).
  /// https://openrouter.ai/baidu/ernie-5.5-flash-preview:free
  static const String defaultModel = 'baidu/ernie-5.5-flash-preview:free';

  /// Fallback free alternative model (never used automatically).
  /// Select manually by editing OPENROUTER_MODEL in backend/.env.
  /// https://openrouter.ai/nvidia/nemotron-3-ultra-550b-a55b:free
  static const String fallbackModel = 'nvidia/nemotron-3-ultra-550b-a55b:free';

  /// All configured free-tier model IDs (for UI display / validation).
  static const List<String> freeModels = [
    defaultModel,
    fallbackModel,
  ];

  /// Whether the given model ID is a configured free-tier model.
  static bool isFreeModel(String? modelId) {
    if (modelId == null) return false;
    return freeModels.contains(modelId);
  }

  /// Whether the given model ID ends with the free-tier marker.
  static bool isFreeTierModel(String? modelId) {
    if (modelId == null) return false;
    return modelId.endsWith(':free');
  }

  /// Gets the OpenRouter API key from environment (Flutter-side only).
  /// This is only used if connecting directly to OpenRouter (not via backend).
  /// Returns null if not configured (demo mode).
  static String? get openRouterApiKey {
    // First check Platform.environment (set via --dart-define or system env)
    final envKey = Platform.environment['OPENROUTER_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }
    return null;
  }

  /// Whether the AI integration is configured with an API key on the Flutter side.
  /// This is NOT the primary check - the app uses a backend proxy that holds the key.
  /// This getter is kept for backwards compatibility.
  static bool get isConfigured => openRouterApiKey != null;

  /// HTTP headers for OpenRouter requests (direct connection only).
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${openRouterApiKey ?? ''}',
        'HTTP-Referer': 'https://github.com/smartsave',
        'X-Title': 'SmartSave',
      };

  /// Creates a copy of headers with the authorization header removed
  /// (for debugging/display purposes).
  static Map<String, String> get safeHeaders => {
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://github.com/smartsave',
        'X-Title': 'SmartSave',
      };
}
