import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/channel.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  const PlayerScreen({super.key, required this.channel});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  double _volume = 1.0;
  String _currentStatus = 'Ready to play';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializePlayer();
  }

  void _initializePlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = false;
          _currentStatus = _getStatusText(state);
        });
      }
    });
  }

  String _getStatusText(PlayerState state) {
    switch (state) {
      case PlayerState.playing: return 'Now playing';
      case PlayerState.paused: return 'Paused';
      case PlayerState.stopped: return 'Stopped';
      default: return 'Ready';
    }
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      setState(() { _isLoading = true; _currentStatus = 'Buffering...'; });
      try {
        await _audioPlayer.play(UrlSource(widget.channel.url));
      } catch (e) {
        if (mounted) {
          setState(() { _isLoading = false; _currentStatus = 'Playback failed'; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to play: $e')));
        }
      }
    }
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.surface],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Icon(_isPlaying ? Icons.radio : Icons.radio_button_checked, size: 80, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 32),
                Text(widget.channel.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(widget.channel.description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                  child: Text(_currentStatus, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(onPressed: _stop, icon: const Icon(Icons.stop), iconSize: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 32),
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary),
                      child: IconButton(
                        onPressed: _togglePlay,
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        iconSize: 56,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.volume_down),
                    SizedBox(width: 200, child: Slider(value: _volume, onChanged: (v) => setState(() => _volume = v), min: 0, max: 1)),
                    const Icon(Icons.volume_up),
                  ],
                ),
                Text('Volume: ${(_volume * 100).toInt()}%'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
