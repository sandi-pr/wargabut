import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wargabut/app/config/api_keys.dart';

void main() {
  test('Test HTTP API Key', () async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${ApiKeys.geminiApiKey}');
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        "contents": [
          {
            "parts": [
              {"text": "Hello"}
            ]
          }
        ]
      }),
    );

    print('Status: ' + response.statusCode.toString());
    print('Body: ' + response.body);
  });
}
