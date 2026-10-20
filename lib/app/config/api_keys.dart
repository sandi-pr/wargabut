import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  /// Mendapatkan API Key Gemini dari file `.env` (flutter_dotenv)
  /// atau fallback ke `--dart-define=GEMINI_API_KEY=...`.
  ///
  /// Jangan hardcode API Key di file ini agar aman dari secret scanning GitHub.
  static String get geminiApiKey {
    if (dotenv.isInitialized) {
      final key = dotenv.maybeGet('GEMINI_API_KEY');
      if (key != null && key.trim().isNotEmpty) {
        return key.trim();
      }
    }
    return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  }
}
