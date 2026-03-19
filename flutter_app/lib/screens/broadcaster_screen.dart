import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/webrtc_service.dart';

class BroadcasterScreen extends StatefulWidget {
  final Map<String, dynamic> room;

  const BroadcasterScreen({super.key, required this.room});

  @override
  State<BroadcasterScreen> createState() => _BroadcasterScreenState();
}

class _BroadcasterScreenState extends State<BroadcasterScreen> {
  final SocketService _socketService = SocketService();
  final WebRTCService _webrtcService = WebRTCService();
  
  int _listenerCount = 0;
  bool _isOnCall = false;
  String? _callerName;
  String? _callerSocketId;
  dynamic _pendingOffer;
  int? _callTimeLimit; // seconds, null = unlimited
  int _callDuration = 0;
  
  @override
  void initState() {
    super.initState();
    _listenerCount = widget.room['listenerCount'] ?? 0;
    _setupSocketListeners();
    _setupWebRTC();
  }

  void _setupSocketListeners() {
    _socketService.onListenerUpdated = (data) {
      if (mounted && data['roomId'] == widget.room['id']) {
        setState(() {
          _listenerCount = data['listenerCount'] ?? 0;
        });
      }
    };

    _socketService.onIncomingCall = (data) {
      if (mounted) {
        setState(() {
          _callerName = data['callerName'];
          _callerSocketId = data['from'];
          _pendingOffer = data['offer'];
        });
        _showIncomingCallDialog();
      }
    };

    _socketService.onCallEnded = (data) {
      if (mounted) {
        _endCall();
      }
    };

    _socketService.onCallAnswered = (data) {
      if (mounted) {
        _webrtcService.handleAnswer(data['answer']);
      }
    };

    _socketService.onCallIce = (data) {
      if (mounted) {
        _webrtcService.handleIceCandidate(data['candidate']);
      }
    };
  }

  void _setupWebRTC() {
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
      }
    };
  }

  void _showIncomingCallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Incoming Call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_in_talk, size: 60, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              '$_callerName wants to connect',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Time limit options
            const Text('Set time limit:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Unlimited'),
                  selected: _callTimeLimit == null,
                  onSelected: (s) => setState(() => _callTimeLimit = null),
                ),
                ChoiceChip(
                  label: const Text('1 min'),
                  selected: _callTimeLimit == 60,
                  onSelected: (s) => setState(() => _callTimeLimit = 60),
                ),
                ChoiceChip(
                  label: const Text('3 min'),
                  selected: _callTimeLimit == 180,
                  onSelected: (s) => setState(() => _callTimeLimit = 180),
                ),
                ChoiceChip(
                  label: const Text('5 min'),
                  selected: _callTimeLimit == 300,
                  onSelected: (s) => setState(() => _callTimeLimit = 300),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectCall();
            },
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptCall();
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptCall() async {
    if (_callerSocketId == null || _pendingOffer == null) return;

    try {
      await _webrtcService.initialize();
      await _webrtcService.answerCall(_callerSocketId!, _pendingOffer);
      
      setState(() {
        _isOnCall = true;
        _callDuration = 0;
      });

      // Start timer if limit is set
      if (_callTimeLimit != null) {
        _startCallTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept call: $e')),
        );
      }
    }
  }

  void _rejectCall() {
    if (_callerSocketId != null) {
      _socketService.endCall(_callerSocketId!);
    }
    setState(() {
      _callerName = null;
      _callerSocketId = null;
      _pendingOffer = null;
    });
  }

  void _startCallTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isOnCall) return;
      
      setState(() {
        _callDuration++;
      });

      if (_callTimeLimit != null && _callDuration >= _callTimeLimit!) {
        _endCall();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call ended: time limit reached')),
        );
      } else {
        _startCallTimer();
      }
    });
  }

  void _endCall() {
    if (_callerSocketId != null) {
      _socketService.endCall(_callerSocketId!);
    }
    _webrtcService.endCall();
    
    setState(() {
      _isOnCall = false;
      _callerName = null;
      _callerSocketId = null;
      _pendingOffer = null;
      _callDuration = 0;
    });
  }

  void _endBroadcast() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Broadcast?'),
        content: const Text('Are you sure you want to end your live broadcast?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _socketService.endRoom(widget.room['id'], (response) {
                Navigator.pop(context);
              });
            },
            child: const Text('End'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _endBroadcast();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.room['title'] ?? 'Live'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: _endBroadcast,
              icon: const Icon(Icons.close),
            ),
          ],
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

                  // Listener count
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
                          const Icon(Icons.headphones, color: Colors.white, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            '$_listenerCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'listening',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Call status
                  if (_isOnCall) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone_in_talk, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'On call with $_callerName',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (_callTimeLimit != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Time: ${_formatDuration(_callDuration)} / ${_formatDuration(_callTimeLimit!)}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
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
                  ] else ...[
                    Text(
                      'Waiting for call requests...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _webrtcService.dispose();
    super.dispose();
  }
}
