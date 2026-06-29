import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wargabut/app/config/api_keys.dart';

void main() async {
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=\${ApiKeys.geminiApiKey}');
  try {
    final response = await http.get(url);
    print(response.body);
  } catch (e) {
    print('Error: \$e');
  }
}
