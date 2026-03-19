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
      if (mounted) setState(() => _liveRooms = rooms.cast<Map<String, dynamic>>());
    };
    _socketService.connect(serverUrl);
    setState(() => _isConnected = _socketService.isConnected);
  }

  void _startBroadcast() {
    showDialog(context: context, builder: (context) => _CreateRoomDialog(onCreated: (room) {
      Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BroadcasterScreen(room: room)));
    }));
  }

  void _joinRoom(Map<String, dynamic> room) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListenerLiveScreen(room: room)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Broadcasts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16), child: Icon(_isConnected ? Icons.wifi : Icons.wifi_off, color: _isConnected ? Colors.green : Colors.grey)),
        ],
      ),
      body: _liveRooms.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.radio, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('No live broadcasts', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text('Be the first to go live!', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500])),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _liveRooms.length,
              itemBuilder: (context, index) {
                final room = _liveRooms[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.teal, child: const Icon(Icons.mic, color: Colors.white)),
                    title: Text(room['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(room['broadcasterName'] ?? 'Unknown'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Text('LIVE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.headphones, size: 16, color: Colors.grey[600]),
                      Text(' ${room['listenerCount'] ?? 0}', style: TextStyle(color: Colors.grey[600])),
                    ]),
                    onTap: () => _joinRoom(room),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _startBroadcast, icon: const Icon(Icons.mic), label: const Text('Go Live')),
    );
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
  String _genre = 'Talk';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start Live Broadcast'),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Your Name', border: OutlineInputBorder()), validator: (v) => v?.isEmpty == true ? 'Required' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Stream Title', border: OutlineInputBorder()), validator: (v) => v?.isEmpty == true ? 'Required' : null),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _genre,
            decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder()),
            items: ['Talk', 'Music', 'News', 'Sports'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => _genre = v!),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (_formKey.currentState!.validate()) {
            SocketService().createRoom(
              broadcasterName: _nameController.text,
              title: _titleController.text,
              genre: _genre,
              callback: (response) {
                if (response['error'] != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['error'])));
                } else {
                  widget.onCreated(response['room']);
                }
              },
            );
          }
        }, child: const Text('Start')),
      ],
    );
  }
}
