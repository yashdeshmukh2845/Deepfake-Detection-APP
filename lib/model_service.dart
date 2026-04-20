import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// This Service handles Image Picking and API communication with FastAPI
class ModelService {
  // Use http://10.0.2.2 for Android Emulator, and localhost for Web/Windows
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

  // Function to pick an image from the device
  Future<XFile?> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      return image;
    } catch (e) {
      print("Error picking image: $e");
      return null;
    }
  }

  // Function to pick a video from the device
  Future<XFile?> pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _picker.pickVideo(source: source);
      return video;
    } catch (e) {
      print("Error picking video: $e");
      return null;
    }
  }

  // Function to send the image to our FastAPI server
  Future<Map<String, dynamic>> runInference(XFile file) async {
    try {
      // 1. Create a Multipart Request (used for uploading files)
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/predict'));
      
      // 2. Add the Image/Video file to the request (handle Web properly)
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes('file', await file.readAsBytes(), filename: file.name));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      // 3. Send the request and wait for response with a 60-second timeout for large videos
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception("Connection timed out. Video analysis may take longer, or the server is down.");
        },

      );
      var response = await http.Response.fromStream(streamedResponse);

      // 4. Check if server returned Success (Status Code 200)
      if (response.statusCode == 200) {
        // Decode the JSON data from the server
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Get 'result' (Real/Fake) and 'confidence' from JSON
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
