import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class ChannelService {
  static const String _baseUrl = 'http://10.0.2.2:3000/api';

  Future<List<Channel>> getChannels() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/channels'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Channel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load channels: ${response.statusCode}');
      }
    } catch (e) {
      // Return fallback channels if backend is unavailable
      return _getFallbackChannels();
    }
  }

  Future<Channel?> getChannel(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/channels/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return Channel.fromJson(jsonDecode(response.body));
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<bool> addChannel(Channel channel) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/channels'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(channel.toJson()),
      );

      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteChannel(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/channels/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
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
