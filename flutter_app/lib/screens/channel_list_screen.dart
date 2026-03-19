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
    final channels = await _channelService.getChannels();
    setState(() {
      _channels = channels;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Internet Radio'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _channels.length,
              itemBuilder: (context, index) {
                final channel = _channels[index];
                return ChannelTile(channel: channel);
              },
            ),
    );
  }
}

class ChannelTile extends StatelessWidget {
  final Channel channel;

  const ChannelTile({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getGenreColor(channel.genre),
          child: Text(
            channel.name.isNotEmpty ? channel.name[0] : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(channel.name),
        subtitle: Text(channel.description),
        trailing: Chip(
          label: Text(channel.genre),
          backgroundColor: _getGenreColor(channel.genre).withOpacity(0.2),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(channel: channel),
            ),
          );
        },
      ),
    );
  }

  Color _getGenreColor(String genre) {
    switch (genre.toLowerCase()) {
      case 'news':
        return Colors.red;
      case 'classical':
        return Colors.brown;
      case 'jazz':
        return Colors.blue;
      case 'alternative':
        return Colors.purple;
      case 'electronic':
        return Colors.orange;
      case 'lo-fi':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }
}
