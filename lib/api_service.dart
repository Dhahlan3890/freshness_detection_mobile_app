import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static Future<String> getApiEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_endpoint') ?? 'https://fyp-fast-api-backend.onrender.com/predict';
  }

  static Future<Map<String, dynamic>> analyzeFreshness(File imageFile) async {
    try {
      final apiUrl = await getApiEndpoint();
      
      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      
      // Add file to request
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      
      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to analyze image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error analyzing image: $e');
    }
  }
}
