import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ModelService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://127.0.0.1:8000";
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8000";
    } else {
      return "http://127.0.0.1:8000";
    }
  }
  
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      return image;
    } catch (e) {
      print("Error picking image: $e");
      return null;
    }
  }

  Future<XFile?> pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _picker.pickVideo(source: source);
      return video;
    } catch (e) {
      print("Error picking video: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> runInference(XFile file) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/predict'));
      
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes('file', await file.readAsBytes(), filename: file.name));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception("Connection timed out. Video analysis may take longer, or the server is down.");
        },

      );
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        return {
          "result": data['result'] ?? "Unknown",
          "confidence": data['confidence'] ?? "0.00",
          "message": data['message'] ?? (data['result'] == 'Error' ? "Analysis Failed" : "Analysis Successful"),
        };
      } else {
        return {
          "result": "Error",
          "confidence": "0.00",
          "message": "Server error: ${response.statusCode}",
        };
      }
    } catch (e) {
      return {
        "result": "Error",
        "confidence": "0.00",
        "message": "Could not connect to FastAPI server at $baseUrl",
      };
    }
  }
}
