import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class ChannelService {
  // Use 10.0.2.2 for Android emulator, localhost for iOS simulator
  // TODO: Make this configurable via environment variables
  static String get baseUrl {
    // Can be overridden by setting an environment variable
    const String envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    return envBaseUrl.isNotEmpty ? envBaseUrl : 'http://10.0.2.2:3000';
  }

  static const Duration _timeout = Duration(seconds: 10);

  Future<List<Channel>> getChannels() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/channels'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Channel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load channels: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      // Log network errors for debugging
      debugPrint('Network error: $e');
      return _getFallbackChannels();
    } catch (e) {
      // Log other errors but still return fallback
      debugPrint('Error loading channels: $e');
      return _getFallbackChannels();
    }
  }

  List<Channel> _getFallbackChannels() {
    return [
      Channel(
        id: '1',
        name: 'BBC World Service',
        description: 'International news and analysis from the BBC',
        url: 'https://stream.live.vc.bbcmedia.co.uk/bbc_world_service',
        genre: 'News',
      ),
      Channel(
        id: '2',
        name: 'NPR News',
        description: 'National Public Radio - breaking news and analysis',
        url: 'https://npr-ice.streamguys1.com/live.mp3',
        genre: 'News',
      ),
      Channel(
        id: '3',
        name: 'Classic FM',
        description: 'The UK\'s favourite classical music station',
        url: 'https://media-ice.musicradio.com/ClassicFMMP3',
        genre: 'Classical',
      ),
      Channel(
        id: '4',
        name: 'Jazz FM',
        description: 'The home of smooth jazz and soul',
        url: 'https://edge-bauerall-01-gos2.sharp-stream.com/jazz.mp3',
        genre: 'Jazz',
      ),
      Channel(
        id: '5',
        name: 'KEXP',
        description: 'Seattle\'s premier independent music station',
        url: 'https://kexp-mp3-128.streamguys1.com/kexp128.mp3',
        genre: 'Alternative',
      ),
    ];
  }
}
