import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import 'broadcaster_screen.dart';
import 'listener_live_screen.dart';

class LiveListScreen extends StatefulWidget {
  const LiveListScreen({super.key});

  @override
  State<LiveListScreen> createState() => _LiveListScreenState();
}

class _LiveListScreenState extends State<LiveListScreen> {
  final SocketService _socketService = SocketService();
  List<Map<String, dynamic>> _liveRooms = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectToSocket();
  }

  void _connectToSocket() {
    const serverUrl = 'http://10.0.2.2:3000';

    _socketService.onRoomsUpdated = (rooms) {
      if (mounted) {
        setState(() {
          _liveRooms = rooms.cast<Map<String, dynamic>>();
        });
      }
    };

    _socketService.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Socket error: $error')),
        );
      }
    };

    _socketService.connect(serverUrl);

    setState(() {
      _isConnected = _socketService.isConnected;
    });
  }

  void _startBroadcast() {
    showDialog(
      context: context,
      builder: (context) => _CreateRoomDialog(
        onCreated: (room) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BroadcasterScreen(room: room),
            ),
          );
        },
      ),
    );
  }

  void _joinRoom(Map<String, dynamic> room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ListenerLiveScreen(room: room),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Broadcasts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isConnected ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
      body: _liveRooms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radio, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No live broadcasts',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to go live!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _liveRooms.length,
              itemBuilder: (context, index) {
                final room = _liveRooms[index];
                return _LiveRoomCard(
                  room: room,
                  onTap: () => _joinRoom(room),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startBroadcast,
        icon: const Icon(Icons.mic),
        label: const Text('Go Live'),
      ),
    );
  }
}

class _LiveRoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;

  const _LiveRoomCard({
    required this.room,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getGenreColor(room['genre'] ?? 'General'),
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room['title'] ?? 'Untitled',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room['broadcasterName'] ?? 'Unknown',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    if (room['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        room['description'],
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.headphones, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${room['listenerCount'] ?? 0}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGenreColor(String genre) {
    switch (genre.toLowerCase()) {
      case 'news':
        return Colors.blue;
      case 'music':
        return Colors.purple;
      case 'talk':
        return Colors.orange;
      case 'sports':
        return Colors.green;
      default:
        return Colors.teal;
    }
  }
}

class _CreateRoomDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onCreated;

  const _CreateRoomDialog({required this.onCreated});

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _genre = 'Talk';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start Live Broadcast'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Stream Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _genre,
                decoration: const InputDecoration(
                  labelText: 'Genre',
                  border: OutlineInputBorder(),
                ),
                items: ['Talk', 'Music', 'News', 'Sports', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _genre = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final socketService = SocketService();
              socketService.createRoom(
                broadcasterName: _nameController.text,
                title: _titleController.text,
                description: _descController.text.isEmpty ? null : _descController.text,
                genre: _genre,
                callback: (response) {
                  if (response['error'] != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(response['error'])),
                    );
                  } else {
                    widget.onCreated(response['room']);
                  }
                },
              );
            }
          },
          child: const Text('Start'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }
}
