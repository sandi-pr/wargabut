import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:wargabut/app/config/api_keys.dart';

void main() {
  test('Test API Key', () async {
    print('Testing API Key...');
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: ApiKeys.geminiApiKey,
      );
      final response = await model.generateContent([Content.text('Hello')]);
      print('Success: ${response.text}');
    } catch (e) {
      print('Error: $e');
    }
  });
}