import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../services/channel_service.dart';
import 'player_screen.dart';

class ChannelListScreen extends StatefulWidget {
  const ChannelListScreen({super.key});
  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  final ChannelService _channelService = ChannelService();
  List<Channel> _channels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final channels = await _channelService.getChannels();
      if (mounted) {
        setState(() {
          _channels = channels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radio Stations'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _channels.length,
              itemBuilder: (context, index) {
                final channel = _channels[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getGenreColor(channel.genre),
                      child: const Icon(Icons.radio, color: Colors.white),
                    ),
                    title: Text(channel.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(channel.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Chip(label: Text(channel.genre)),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel)));
                    },
                  ),
                );
              },
            ),
    );
  }

  Color _getGenreColor(String genre) {
    switch (genre.toLowerCase()) {
      case 'news': return Colors.blue;
      case 'classical': return Colors.purple;
      case 'jazz': return Colors.orange;
      case 'alternative': return Colors.teal;
      default: return Colors.grey;
    }
  }
}
