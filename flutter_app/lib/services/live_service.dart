import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/live_room.dart';

class LiveService {
  // For Android emulator, use 10.0.2.2
  // For iOS simulator, use localhost
  // For real devices, use your computer's IP address
  static const String _baseUrl = 'http://10.0.2.2:3000/api';

  Future<List<LiveRoom>> getActiveRooms() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/live'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => LiveRoom.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load rooms: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to server: $e');
    }
  }

  Future<LiveRoom> createRoom({
    required String broadcasterName,
    required String title,
    String? description,
    String? genre,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/live'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'broadcasterName': broadcasterName,
          'title': title,
          'description': description,
          'genre': genre,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return LiveRoom.fromJson(data);
      } else {
        throw Exception('Failed to create room: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to server: $e');
    }
  }

  Future<void> endRoom(String roomId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/live/$roomId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to end room: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to server: $e');
    }
  }
}
