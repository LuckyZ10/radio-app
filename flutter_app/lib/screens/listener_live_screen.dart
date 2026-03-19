import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/webrtc_service.dart';

class ListenerLiveScreen extends StatefulWidget {
  final Map<String, dynamic> room;

  const ListenerLiveScreen({super.key, required this.room});

  @override
  State<ListenerLiveScreen> createState() => _ListenerLiveScreenState();
}

class _ListenerLiveScreenState extends State<ListenerLiveScreen> {
  final SocketService _socketService = SocketService();
  final WebRTCService _webrtcService = WebRTCService();
  
  int _listenerCount = 0;
  bool _isOnCall = false;
  bool _isRequestingCall = false;
  double _volume = 1.0;
  
  @override
  void initState() {
    super.initState();
    _listenerCount = widget.room['listenerCount'] ?? 0;
    _joinRoom();
    _setupSocketListeners();
    _setupWebRTC();
  }

  void _joinRoom() {
    _socketService.joinRoom(widget.room['id']);
  }

  void _setupSocketListeners() {
    _socketService.onListenerUpdated = (data) {
      if (mounted && data['roomId'] == widget.room['id']) {
        setState(() {
          _listenerCount = data['listenerCount'] ?? 0;
        });
      }
    };

    _socketService.onRoomEnded = (data) {
      if (mounted && data['roomId'] == widget.room['id']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcast has ended')),
        );
        Navigator.pop(context);
      }
    };

    _socketService.onCallAnswered = (data) {
      if (mounted) {
        _webrtcService.handleAnswer(data['answer']);
        setState(() {
          _isOnCall = true;
          _isRequestingCall = false;
        });
      }
    };

    _socketService.onCallIce = (data) {
      if (mounted) {
        _webrtcService.handleIceCandidate(data['candidate']);
      }
    };

    _socketService.onCallEnded = (data) {
      if (mounted) {
        _endCall();
      }
    };
  }

  void _setupWebRTC() {
    _webrtcService.onRemoteStream = (stream) {
      // Handle remote audio stream
      // In a real app, you'd connect this to an audio player
    };

    _webrtcService.onCallEnded = () {
      if (mounted) {
        _endCall();
      }
    };

    _webrtcService.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call error: $error')),
        );
        setState(() {
          _isRequestingCall = false;
        });
      }
    };
  }

  Future<void> _requestCall() async {
    final broadcasterSocketId = widget.room['broadcasterSocketId'];
    if (broadcasterSocketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Broadcaster is not available')),
      );
      return;
    }

    try {
      setState(() {
        _isRequestingCall = true;
      });

      await _webrtcService.initialize();
      
      // Create offer and send to broadcaster
      await _webrtcService.createCall(
        broadcasterSocketId,
        'Listener', // In a real app, use the user's name
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request call: $e')),
        );
        setState(() {
          _isRequestingCall = false;
        });
      }
    }
  }

  void _endCall() {
    final broadcasterSocketId = widget.room['broadcasterSocketId'];
    if (broadcasterSocketId != null) {
      _socketService.endCall(broadcasterSocketId);
    }
    _webrtcService.endCall();
    
    setState(() {
      _isOnCall = false;
      _isRequestingCall = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room['title'] ?? 'Live'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Live indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Broadcaster info
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mic, color: Colors.white, size: 50),
                        const SizedBox(height: 8),
                        Text(
                          widget.room['broadcasterName'] ?? 'Broadcaster',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title and description
                Text(
                  widget.room['title'] ?? '',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (widget.room['description'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.room['description'],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),

                // Listener count
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.headphones, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '$_listenerCount listening',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // Call status / button
                if (_isOnCall) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_in_talk, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Connected to broadcaster',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _endCall,
                    icon: const Icon(Icons.call_end),
                    label: const Text('End Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else if (_isRequestingCall) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Requesting to connect...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: _requestCall,
                    icon: const Icon(Icons.phone),
                    label: const Text('Request to Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Request a live conversation with the broadcaster',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
                const SizedBox(height: 32),

                // Volume control
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volume_down),
                        SizedBox(
                          width: 200,
                          child: Slider(
                            value: _volume,
                            onChanged: (v) {
                              setState(() {
                                _volume = v;
                              });
                              // In a real app, adjust audio volume here
                            },
                            min: 0.0,
                            max: 1.0,
                          ),
                        ),
                        const Icon(Icons.volume_up),
                      ],
                    ),
                    Text('Volume: ${(_volume * 100).toInt()}%'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socketService.leaveRoom(widget.room['id']);
    _webrtcService.dispose();
    super.dispose();
  }
}
