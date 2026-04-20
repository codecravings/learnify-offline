/// API key configuration.
/// In production, these should be loaded from environment variables or secure storage.
/// For development, create a file `lib/core/config/api_keys_dev.dart` with actual keys.
class ApiKeys {
  ApiKeys._();

  // Set these via --dart-define or replace in api_keys_dev.dart
  static const String groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  static const String hindsightApiKey = String.fromEnvironment(
    'HINDSIGHT_API_KEY',
    defaultValue: '',
  );

  static const String deepseekApiKey = String.fromEnvironment(
    'DEEPSEEK_API_KEY',
    defaultValue: '',
  );

  static const String hindsightBaseUrl = 'https://api.hindsight.vectorize.io';
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1';
  static const String deepseekBaseUrl = 'https://api.deepseek.com/v1';
}
