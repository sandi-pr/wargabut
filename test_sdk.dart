import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:wargabut/app/config/api_keys.dart';

void main() async {
  print('Testing API Key...');
  try {
    final model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: ApiKeys.geminiApiKey,
    );
    final response = await model.generateContent([Content.text('Hello')]);
    print('Success: ' + response.text.toString());
  } catch (e) {
    print('Error Exception: ' + e.toString());
  }
}
