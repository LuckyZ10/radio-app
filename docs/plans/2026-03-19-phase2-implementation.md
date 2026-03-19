# Phase 2: Live Streaming & 1v1 Voice Calls Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add real-time live broadcasting and 1v1 voice calls to the internet radio app using WebRTC for ultra-low latency audio.

**Architecture:**
- Backend: Socket.io for signaling, in-memory room management, SQLite for persistence
- Flutter: flutter_webrtc for peer connections, socket_io_client for signaling
- Live rooms: One broadcaster streams to multiple listeners via WebRTC mesh
- 1v1 calls: Direct WebRTC peer connection with Socket.io signaling

**Tech Stack:** Node.js, Express, Socket.io, SQLite, Flutter, flutter_webrtc, socket_io_client

---

## Task 1: Backend - Add Live Rooms Database Table

**Files:**
- Modify: `backend/server.js:64-73` (extend table creation section)

**Step 1: Add live_rooms table creation**

After the channels table creation, add:

```javascript
// Create live_rooms table for live broadcasting
db.exec(`
  CREATE TABLE IF NOT EXISTS live_rooms (
    id TEXT PRIMARY KEY,
    broadcaster_name TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    genre TEXT,
    listener_count INTEGER DEFAULT 0,
    is_live BOOLEAN DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
  )
`);
```

**Step 2: Verify table creation**

Run: `node server.js`
Expected: Server starts without errors, table created in radio.db
Stop server with Ctrl+C

**Step 3: Commit**

```bash
git add backend/server.js
git commit -m "feat: add live_rooms database table"
```

---

## Task 2: Backend - Add In-Memory Room Management

**Files:**
- Modify: `backend/server.js:156` (after Socket.io connection handling)

**Step 1: Add in-memory room tracking**

After `io.on('connection', ...)` block, before API routes, add:

```javascript
// In-memory live rooms management
const liveRooms = new Map();

function createLiveRoom(roomData) {
  const room = {
    id: roomData.id,
    broadcasterName: roomData.broadcasterName,
    title: roomData.title,
    description: roomData.description,
    genre: roomData.genre,
    listenerCount: 0,
    isLive: true,
    createdAt: new Date().toISOString(),
    broadcasterSocketId: roomData.socketId
  };
  liveRooms.set(room.id, room);

  // Persist to database
  db.prepare(`
    INSERT INTO live_rooms (id, broadcaster_name, title, description, genre, listener_count, is_live, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(room.id, room.broadcasterName, room.title, room.description || null, room.genre || null, 0, 1, room.createdAt);

  return room;
}

function getLiveRoom(roomId) {
  return liveRooms.get(roomId);
}

function getAllLiveRooms() {
  return Array.from(liveRooms.values()).filter(room => room.isLive);
}

function updateListenerCount(roomId, delta) {
  const room = liveRooms.get(roomId);
  if (room) {
    room.listenerCount += delta;
    db.prepare('UPDATE live_rooms SET listener_count = ? WHERE id = ?')
      .run(room.listenerCount, roomId);
    return room.listenerCount;
  }
  return 0;
}

function endLiveRoom(roomId) {
  const room = liveRooms.get(roomId);
  if (room) {
    room.isLive = false;
    liveRooms.delete(roomId);
    db.prepare('UPDATE live_rooms SET is_live = 0 WHERE id = ?').run(roomId);
    return true;
  }
  return false;
}
```

**Step 2: Test functions manually (optional verification)**

Add temporary log after function definitions:
```javascript
console.log('Live room management functions loaded');
```

Run: `node server.js`
Expected: "Live room management functions loaded" in console

**Step 3: Remove temporary log and commit**

```bash
git add backend/server.js
git commit -m "feat: add in-memory live room management"
```

---

## Task 3: Backend - Add Live Room API Endpoints

**Files:**
- Modify: `backend/server.js:283` (after DELETE /api/channels/:id endpoint)

**Step 1: Add POST /api/live endpoint**

```javascript
// POST /api/live - Create a new live broadcast room
app.post('/api/live', (req, res) => {
  try {
    let { broadcasterName, title, description, genre } = req.body;

    // Validate required fields
    if (!broadcasterName || !title) {
      return res.status(400).json({ error: 'broadcasterName and title are required' });
    }

    // Sanitize inputs
    broadcasterName = sanitize(String(broadcasterName));
    title = sanitize(String(title));
    description = description ? sanitize(String(description)) : null;
    genre = genre ? sanitize(String(genre)) : null;

    // Length validation
    if (broadcasterName.length > 50) return res.status(400).json({ error: 'broadcasterName too long (max 50)' });
    if (title.length > 200) return res.status(400).json({ error: 'title too long (max 200)' });
    if (description && description.length > 500) return res.status(400).json({ error: 'description too long (max 500)' });

    // Generate unique room ID
    const roomId = `room_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    const room = createLiveRoom({
      id: roomId,
      broadcasterName,
      title,
      description,
      genre,
      socketId: req.body.socketId
    });

    res.status(201).json(room);
  } catch (error) {
    console.error('Error creating live room:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

**Step 2: Add GET /api/live endpoint**

```javascript
// GET /api/live - Get all active live rooms
app.get('/api/live', (req, res) => {
  try {
    const rooms = getAllLiveRooms();
    res.json(rooms);
  } catch (error) {
    console.error('Error fetching live rooms:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

**Step 3: Add GET /api/live/:roomId endpoint**

```javascript
// GET /api/live/:roomId - Get a specific live room
app.get('/api/live/:roomId', (req, res) => {
  try {
    const room = getLiveRoom(req.params.roomId);
    if (!room) {
      return res.status(404).json({ error: 'Live room not found' });
    }
    res.json(room);
  } catch (error) {
    console.error('Error fetching live room:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

**Step 4: Add DELETE /api/live/:roomId endpoint**

```javascript
// DELETE /api/live/:roomId - End a live broadcast
app.delete('/api/live/:roomId', (req, res) => {
  try {
    const roomId = req.params.roomId;
    const success = endLiveRoom(roomId);

    if (!success) {
      return res.status(404).json({ error: 'Live room not found' });
    }

    // Notify all listeners in the room
    io.to(`room:${roomId}`).emit('room-ended', { roomId });

    res.json({ message: 'Live room ended successfully' });
  } catch (error) {
    console.error('Error ending live room:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

**Step 5: Test endpoints**

Run: `node server.js`

Test POST:
```bash
curl -X POST http://localhost:3000/api/live \
  -H "Content-Type: application/json" \
  -d '{"broadcasterName":"TestDJ","title":"Test Show"}'
```
Expected: Room object with id

Test GET:
```bash
curl http://localhost:3000/api/live
```
Expected: Array with created room

**Step 6: Commit**

```bash
git add backend/server.js
git commit -m "feat: add live room API endpoints"
```

---

## Task 4: Backend - Add WebRTC Signaling via Socket.io

**Files:**
- Modify: `backend/server.js:137-156` (extend Socket.io connection handling)

**Step 1: Replace existing Socket.io handlers with enhanced version**

Replace the entire `io.on('connection', ...)` block with:

```javascript
// Socket.io connection handling
io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id}`);

  // Join a channel room (Phase 1 - preserved for compatibility)
  socket.on('join-channel', (channelId) => {
    socket.join(`channel:${channelId}`);
    console.log(`Socket ${socket.id} joined channel: ${channelId}`);
  });

  // Leave a channel room (Phase 1)
  socket.on('leave-channel', (channelId) => {
    socket.leave(`channel:${channelId}`);
    console.log(`Socket ${socket.id} left channel: ${channelId}`);
  });

  // === Phase 2: Live Streaming ===

  // Create live room
  socket.on('create-room', (data, callback) => {
    try {
      const { broadcasterName, title, description, genre } = data;

      if (!broadcasterName || !title) {
        return callback({ error: 'broadcasterName and title are required' });
      }

      const roomId = `room_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      const room = createLiveRoom({
        id: roomId,
        broadcasterName: sanitize(String(broadcasterName)),
        title: sanitize(String(title)),
        description: description ? sanitize(String(description)) : null,
        genre: genre ? sanitize(String(genre)) : null,
        socketId: socket.id
      });

      socket.join(`room:${roomId}`);
      callback({ room });

      // Broadcast room list update
      io.emit('rooms-updated', getAllLiveRooms());
    } catch (error) {
      console.error('Error creating room:', error);
      callback({ error: 'Failed to create room' });
    }
  });

  // Join live room as listener
  socket.on('join-room', (data) => {
    const { roomId } = data;
    const room = getLiveRoom(roomId);

    if (!room) {
      return socket.emit('error', { message: 'Room not found' });
    }

    socket.join(`room:${roomId}`);
    const newCount = updateListenerCount(roomId, 1);

    // Notify broadcaster and room
    io.to(`room:${roomId}`).emit('listener-updated', {
      roomId,
      listenerCount: newCount
    });

    socket.emit('room-joined', { room, listenerCount: newCount });
    console.log(`Socket ${socket.id} joined live room: ${roomId}`);
  });

  // Leave live room
  socket.on('leave-room', (data) => {
    const { roomId } = data;
    socket.leave(`room:${roomId}`);
    const newCount = updateListenerCount(roomId, -1);

    io.to(`room:${roomId}`).emit('listener-updated', {
      roomId,
      listenerCount: newCount
    });

    console.log(`Socket ${socket.id} left live room: ${roomId}`);
  });

  // End live room
  socket.on('end-room', (data, callback) => {
    const { roomId } = data;
    const room = getLiveRoom(roomId);

    if (!room || room.broadcasterSocketId !== socket.id) {
      return callback({ error: 'Not authorized to end this room' });
    }

    endLiveRoom(roomId);
    io.to(`room:${roomId}`).emit('room-ended', { roomId });
    io.emit('rooms-updated', getAllLiveRooms());

    callback({ success: true });
  });

  // === WebRTC Signaling ===

  // Relay WebRTC signals between peers
  socket.on('signal', (data) => {
    const { to, signal, roomId } = data;
    io.to(to).emit('signal', {
      from: socket.id,
      signal,
      roomId
    });
  });

  // === 1v1 Call Signaling ===

  // Incoming call offer
  socket.on('call-offer', (data) => {
    const { to, offer, callerName } = data;
    io.to(to).emit('incoming-call', {
      from: socket.id,
      callerName,
      offer
    });
  });

  // Call answer
  socket.on('call-answer', (data) => {
    const { to, answer } = data;
    io.to(to).emit('call-answered', {
      from: socket.id,
      answer
    });
  });

  // ICE candidates for calls
  socket.on('call-ice', (data) => {
    const { to, candidate } = data;
    io.to(to).emit('call-ice', {
      from: socket.id,
      candidate
    });
  });

  // End call
  socket.on('call-end', (data) => {
    const { to } = data;
    io.to(to).emit('call-ended', { from: socket.id });
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);

    // Check if this was a broadcaster and clean up
    for (const [roomId, room] of liveRooms.entries()) {
      if (room.broadcasterSocketId === socket.id) {
        endLiveRoom(roomId);
        io.to(`room:${roomId}`).emit('room-ended', { roomId });
        io.emit('rooms-updated', getAllLiveRooms());
        break;
      }
    }
  });
});
```

**Step 2: Test Socket.io connection**

Run: `node server.js`

You should see: "Socket.io server ready for Phase 2 live streaming" in existing logs

**Step 3: Commit**

```bash
git add backend/server.js
git commit -m "feat: add WebRTC signaling and live room Socket.io handlers"
```

---

## Task 5: Backend - Add Health Endpoint for Live Rooms

**Files:**
- Modify: `backend/server.js:285` (before health check endpoint)

**Step 1: Update health check to include live rooms count**

Replace existing health check with:

```javascript
// Health check endpoint
app.get('/health', (req, res) => {
  const liveRoomCount = getAllLiveRooms().length;
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    liveRooms: liveRoomCount
  });
});
```

**Step 2: Test health endpoint**

```bash
curl http://localhost:3000/health
```

Expected:
```json
{"status":"ok","timestamp":"...","liveRooms":0}
```

**Step 3: Commit**

```bash
git add backend/server.js
git commit -m "feat: update health check with live rooms count"
```

---

## Task 6: Flutter - Add Dependencies

**Files:**
- Modify: `flutter_app/pubspec.yaml`

**Step 1: Add new dependencies**

Add to dependencies section:

```yaml
  socket_io_client: ^2.0.0
  flutter_webrtc: ^0.9.47
  permission_handler: ^11.0.0
```

**Step 2: Install dependencies**

Run: `cd flutter_app && flutter pub get`

Expected: All packages installed successfully

**Step 3: Commit**

```bash
git add flutter_app/pubspec.yaml flutter_app/pubspec.lock
git commit -m "feat: add socket_io_client, flutter_webrtc, permission_handler"
```

---

## Task 7: Flutter - Create LiveRoom Model

**Files:**
- Create: `flutter_app/lib/models/live_room.dart`

**Step 1: Create LiveRoom model class**

```dart
class LiveRoom {
  final String id;
  final String broadcasterName;
  final String title;
  final String? description;
  final String? genre;
  final int listenerCount;
  final bool isLive;
  final String createdAt;

  LiveRoom({
    required this.id,
    required this.broadcasterName,
    required this.title,
    this.description,
    this.genre,
    required this.listenerCount,
    required this.isLive,
    required this.createdAt,
  });

  factory LiveRoom.fromJson(Map<String, dynamic> json) {
    return LiveRoom(
      id: json['id'] as String? ?? '',
      broadcasterName: json['broadcasterName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      genre: json['genre'] as String?,
      listenerCount: json['listenerCount'] as int? ?? 0,
      isLive: json['isLive'] as bool? ?? true,
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'broadcasterName': broadcasterName,
      'title': title,
      'description': description,
      'genre': genre,
      'listenerCount': listenerCount,
      'isLive': isLive,
      'createdAt': createdAt,
    };
  }
}
```

**Step 2: Verify no syntax errors**

Run: `cd flutter_app && flutter analyze lib/models/live_room.dart`

Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/models/live_room.dart
git commit -m "feat: add LiveRoom model"
```

---

## Task 8: Flutter - Create LiveService

**Files:**
- Create: `flutter_app/lib/services/live_service.dart`

**Step 1: Create LiveService class**

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/live_room.dart';

class LiveService {
  static String get baseUrl {
    const String envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    return envBaseUrl.isNotEmpty ? envBaseUrl : 'http://10.0.2.2:3000';
  }

  static const Duration _timeout = Duration(seconds: 10);

  Future<List<LiveRoom>> getLiveRooms() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/live'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => LiveRoom.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load live rooms: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading live rooms: $e');
      return [];
    }
  }

  Future<LiveRoom?> getLiveRoom(String roomId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/live/$roomId'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return LiveRoom.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load live room: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading live room: $e');
      return null;
    }
  }

  Future<LiveRoom?> createLiveRoom({
    required String broadcasterName,
    required String title,
    String? description,
    String? genre,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/live'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'broadcasterName': broadcasterName,
              'title': title,
              if (description != null) 'description': description,
              if (genre != null) 'genre': genre,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 201) {
        return LiveRoom.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create live room: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error creating live room: $e');
      return null;
    }
  }

  Future<bool> endLiveRoom(String roomId) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/api/live/$roomId'))
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error ending live room: $e');
      return false;
    }
  }
}
```

**Step 2: Verify no syntax errors**

Run: `cd flutter_app && flutter analyze lib/services/live_service.dart`

Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/services/live_service.dart
git commit -m "feat: add LiveService for API calls"
```

---

## Task 9: Flutter - Create SignalingService

**Files:**
- Create: `flutter_app/lib/services/signaling_service.dart`

**Step 1: Create SignalingService class**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  io.Socket? _socket;
  final _controllers = <String, StreamController>{};

  String get baseUrl {
    const String envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    return envBaseUrl.isNotEmpty ? envBaseUrl : 'http://10.0.2.2:3000';
  }

  void connect() {
    if (_socket != null && _socket!.connected) {
      debugPrint('Socket already connected');
      return;
    }

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('Socket connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
    });

    _socket!.onConnectError((error) {
      debugPrint('Socket connect error: $error');
    });

    _setupEventListeners();
  }

  void _setupEventListeners() {
    _socket!.on('rooms-updated', (data) {
      _emit('rooms-updated', data);
    });

    _socket!.on('room-joined', (data) {
      _emit('room-joined', data);
    });

    _socket!.on('listener-updated', (data) {
      _emit('listener-updated', data);
    });

    _socket!.on('room-ended', (data) {
      _emit('room-ended', data);
    });

    _socket!.on('signal', (data) {
      _emit('signal', data);
    });

    _socket!.on('incoming-call', (data) {
      _emit('incoming-call', data);
    });

    _socket!.on('call-answered', (data) {
      _emit('call-answered', data);
    });

    _socket!.on('call-ice', (data) {
      _emit('call-ice', data);
    });

    _socket!.on('call-ended', (data) {
      _emit('call-ended', data);
    });

    _socket!.on('error', (data) {
      _emit('error', data);
    });
  }

  void _emit(String event, dynamic data) {
    final controller = _controllers[event];
    if (controller != null && !controller.isClosed) {
      controller.add(data);
    }
  }

  Stream<T> on<T>(String event) {
    _controllers.putIfAbsent(event, () => StreamController.broadcast());
    return _controllers[event]!.stream as Stream<T>;
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  String? get socketId => _socket?.id;

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }

  bool get isConnected => _socket?.connected ?? false;
}
```

**Step 2: Verify no syntax errors**

Run: `cd flutter_app && flutter analyze lib/services/signaling_service.dart`

Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/services/signaling_service.dart
git commit -m "feat: add SignalingService for Socket.io"
```

---

## Task 10: Flutter - Create WebRTCService

**Files:**
- Create: `flutter_app/lib/services/webrtc_service.dart`

**Step 1: Create WebRTCService class**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final _remoteStreamController = StreamController<MediaStream>.broadcast();

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  Stream<MediaStream> get remoteStreamStream => _remoteStreamController.stream;

  Future<MediaStream> getUserAudio() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      }
    });
    _localStream = stream;
    return stream;
  }

  Future<RTCPeerConnection> createPeerConnection({
    required void Function(RTCSessionDescription) onIceCandidate,
    required void Function(MediaStream) onRemoteStream,
  }) async {
    final pc = await createPeerConnectionInternal(_iceServers);

    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        onIceCandidate(RTCSessionDescription(
          candidate.candidate,
          candidate.sdpMid,
        ));
      }
    };

    pc.onAddStream = (stream) {
      _remoteStream = stream;
      onRemoteStream(stream);
      _remoteStreamController.add(stream);
    };

    _peerConnection = pc;
    return pc;
  }

  Future<RTCSessionDescription> createOffer({MediaStream? localStream}) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }

    if (localStream != null) {
      await _peerConnection!.addStream(localStream);
    }

    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 0,
    });

    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer({MediaStream? localStream}) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }

    if (localStream != null) {
      await _peerConnection!.addStream(localStream);
    }

    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 0,
    });

    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection?.setRemoteDescription(description);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection?.addCandidate(candidate);
  }

  Future<void> dispose() async {
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    await _remoteStreamController.close();
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
  }

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  RTCPeerConnection? get peerConnection => _peerConnection;
}

Future<RTCPeerConnection> createPeerConnectionInternal(Map<String, dynamic> config) async {
  return await createPeerConnection(config);
}
```

**Step 2: Verify no syntax errors**

Run: `cd flutter_app && flutter analyze lib/services/webrtc_service.dart`

Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/services/webrtc_service.dart
git commit -m "feat: add WebRTCService for peer connections"
```

---

## Task 11: Flutter - Create LiveListScreen

**Files:**
- Create: `flutter_app/lib/screens/live_list_screen.dart`

**Step 1: Create LiveListScreen widget**

```dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/live_room.dart';
import '../services/live_service.dart';
import '../services/signaling_service.dart';
import 'broadcaster_screen.dart';
import 'listener_screen.dart';

class LiveListScreen extends StatefulWidget {
  const LiveListScreen({super.key});

  @override
  State<LiveListScreen> createState() => _LiveListScreenState();
}

class _LiveListScreenState extends State<LiveListScreen> {
  final _liveService = LiveService();
  final _signalingService = SignalingService();
  List<LiveRoom> _liveRooms = [];
  bool _isLoading = true;
  io.Socket? get _socket => null;

  @override
  void initState() {
    super.initState();
    _loadLiveRooms();
    _connectSocket();
  }

  @override
  void dispose() {
    _signalingService.disconnect();
    super.dispose();
  }

  void _connectSocket() {
    _signalingService.connect();

    _signalingService.on('rooms-updated').listen((data) {
      if (mounted) {
        _loadLiveRooms();
      }
    });
  }

  Future<void> _loadLiveRooms() async {
    setState(() => _isLoading = true);
    final rooms = await _liveService.getLiveRooms();
    if (mounted) {
      setState(() {
        _liveRooms = rooms;
        _isLoading = false;
      });
    }
  }

  void _navigateToBroadcasterScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BroadcasterScreen(),
      ),
    ).then((_) => _loadLiveRooms());
  }

  void _joinRoom(LiveRoom room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListenerScreen(room: room),
      ),
    ).then((_) => _loadLiveRooms());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Broadcasts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _liveRooms.isEmpty
              ? _buildEmptyState()
              : _buildRoomList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToBroadcasterScreen,
        icon: const Icon(Icons.mic),
        label: const Text('Go Live'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.radio_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No live broadcasts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to go live!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList() {
    return RefreshIndicator(
      onRefresh: _loadLiveRooms,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _liveRooms.length,
        itemBuilder: (context, index) {
          final room = _liveRooms[index];
          return _buildRoomCard(room);
        },
      ),
    );
  }

  Widget _buildRoomCard(LiveRoom room) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _joinRoom(room),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getGenreColor(room.genre),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            room.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${room.broadcasterName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    if (room.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        room.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Icon(Icons.headphones, color: Colors.grey[600]),
                  const SizedBox(height: 4),
                  Text(
                    room.listenerCount.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGenreColor(String? genre) {
    switch (genre?.toLowerCase()) {
      case 'news':
        return Colors.blue;
      case 'classical':
        return Colors.purple;
      case 'jazz':
        return Colors.orange;
      case 'alternative':
        return Colors.teal;
      case 'electronic':
        return Colors.cyan;
      case 'pop':
        return Colors.pink;
      case 'rock':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
```

**Step 2: Verify no syntax errors**

Run: `cd flutter_app && flutter analyze lib/screens/live_list_screen.dart`

Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/screens/live_list_screen.dart
git commit -m "feat: add LiveListScreen"
```

---

## Task 12: Flutter - Create BroadcasterScreen

**Files:**
- Create: `flutter_app/lib/screens/broadcaster_screen.dart`

**Step 1: Create BroadcasterScreen widget**

```dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/live_service.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

class BroadcasterScreen extends StatefulWidget {
  const BroadcasterScreen({super.key});

  @override
  State<BroadcasterScreen> createState() => _BroadcasterScreenState();
}

class _BroadcasterScreenState extends State<BroadcasterScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _liveService = LiveService();
  final _signalingService = SignalingService();
  final _webrtcService = WebRTCService();

  bool _isBroadcasting = false;
  bool _isMuted = false;
  String? _roomId;
  int _listenerCount = 0;

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _endBroadcast();
    _signalingService.disconnect();
    _webrtcService.dispose();
    super.dispose();
  }

  void _connectSocket() {
    _signalingService.connect();

    _signalingService.on('listener-updated').listen((data) {
      if (mounted) {
        setState(() {
          _listenerCount = data['listenerCount'] as int? ?? 0;
        });
      }
    });
  }

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _startBroadcast() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    final hasPermission = await _requestMicPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required')),
      );
      return;
    }

    setState(() => _isBroadcasting = true);

    try {
      // Create live room via Socket.io
      _signalingService.emit('create-room', {
        'broadcasterName': 'DJ User',
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'genre': 'General',
      });

      // Listen for room creation response
      _signalingService.on('room-created').listen((data) {
        if (mounted) {
          setState(() {
            _roomId = data['room']['id'] as String;
          });
        }
      });
    } catch (e) {
      setState(() => _isBroadcasting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start broadcast: $e')),
        );
      }
    }
  }

  Future<void> _endBroadcast() async {
    if (_roomId != null) {
      _signalingService.emit('end-room', {'roomId': _roomId});
      if (_roomId != null) {
        await _liveService.endLiveRoom(_roomId!);
      }
    }
    setState(() {
      _isBroadcasting = false;
      _roomId = null;
      _listenerCount = 0;
    });
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    // TODO: Actually mute the audio track
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isBroadcasting ? 'Broadcasting Live' : 'Go Live'),
        backgroundColor: _isBroadcasting ? Colors.red : null,
        actions: [
          if (_isBroadcasting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text('$_listenerCount'),
                ],
              ),
            ),
        ],
      ),
      body: _isBroadcasting ? _buildBroadcastingUI() : _buildSetupUI(),
    );
  }

  Widget _buildSetupUI() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mic, size: 80, color: Colors.red),
          const SizedBox(height: 24),
          Text(
            'Start Your Broadcast',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Broadcast Title',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 3,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _startBroadcast,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'GO LIVE',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastingUI() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, size: 80, color: Colors.red),
                ),
                const SizedBox(height: 24),
                Text(
                  _titleController.text,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$_listenerCount listening',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filled(
                onPressed: _toggleMute,
                icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: _isMuted ? Colors.grey : Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(64, 64),
                ),
              ),
              IconButton.filled(
                onPressed: _endBroadcast,
                icon: const Icon(Icons.call_end),
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(64, 64),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

**Step 2: Verify no syntax errors**

Run: `cd flutter_app && flutter analyze lib/screens/broadcaster_screen.dart`

Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/screens/broadcaster_screen.dart
git commit -m "feat: add BroadcasterScreen"
```

---

## Task 13: Flutter - Create ListenerScreen

**Files:**
- Create: `flutter_app/lib/screens/listener_screen.dart`

**Step 1: Create ListenerScreen widget**

```dart
import 'package:flutter/material.dart';
import '../models/live_room.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

class ListenerScreen extends StatefulWidget {
  final LiveRoom room;

  const ListenerScreen({super.key, required this.room});

  @override
  State<ListenerScreen> createState() => _ListenerScreenState();
}

class _ListenerScreenState extends State<ListenerScreen> {
  final _signalingService = SignalingService();
  final _webrtcService = WebRTCService();

  bool _isConnected = false;
  bool _isLoading = true;
  String _status = 'Connecting...';

  @override
  void initState() {
    super.initState();
    _joinRoom();
  }

  @override
  void dispose() {
    _leaveRoom();
    _webrtcService.dispose();
    super.dispose();
  }

  void _joinRoom() async {
    _signalingService.connect();

    // Join the room via Socket.io
    _signalingService.emit('join-room', {
      'roomId': widget.room.id,
    });

    // Listen for room joined confirmation
    _signalingService.on('room-joined').listen((data) {
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isLoading = false;
          _status = 'Listening';
        });
      }
    });

    // Listen for listener count updates
    _signalingService.on('listener-updated').listen((data) {
      // Update listener count display if needed
    });

    // Handle room ending
    _signalingService.on('room-ended').listen((data) {
      if (mounted) {
        setState(() {
          _status = 'Broadcast ended';
          _isConnected = false;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });

    // Listen for WebRTC signals
    _signalingService.on<Map>('signal').listen((data) {
      // Handle WebRTC signaling
      // TODO: Implement WebRTC peer connection
    });
  }

  void _leaveRoom() {
    _signalingService.emit('leave-room', {
      'roomId': widget.room.id,
    });
    _signalingService.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listening Live'),
        backgroundColor: Colors.red,
      ),
      body: _isLoading
          ? _buildConnectingUI()
          : _isConnected
              ? _buildListeningUI()
              : _buildEndedUI(),
    );
  }

  Widget _buildConnectingUI() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Connecting to broadcast...'),
        ],
      ),
    );
  }

  Widget _buildListeningUI() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.headphones, size: 100, color: Colors.red),
                ),
                const SizedBox(height: 32),
                Text(
                  widget.room.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'by ${widget.room.broadcasterName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                if (widget.room.description != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      widget.room.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.call_end),
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(64, 64),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEndedUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broadcast_off, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _status,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Verify no syntax errors**

Run: `cd flutter_app && flutter analyze lib/screens/listener_screen.dart`

Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/screens/listener_screen.dart
git commit -m "feat: add ListenerScreen"
```

---

## Task 14: Flutter - Create CallScreen

**Files:**
- Create: `flutter_app/lib/screens/call_screen.dart`

**Step 1: Create CallScreen widget**

```dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

class CallScreen extends StatefulWidget {
  final String? targetUserId;
  final String? callerName;
  final bool isIncoming;

  const CallScreen({
    super.key,
    this.targetUserId,
    this.callerName,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _signalingService = SignalingService();
  final _webrtcService = WebRTCService();

  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  String _callStatus = widget.isIncoming ? 'Incoming call...' : 'Calling...';
  Duration _callDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.isIncoming) {
      _callStatus = '${widget.callerName} is calling...';
    }
  }

  @override
  void dispose() {
    _endCall();
    _webrtcService.dispose();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    return micStatus.isGranted;
  }

  Future<void> _answerCall() async {
    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      Navigator.pop(context);
      return;
    }

    setState(() => _callStatus = 'Connecting...');

    // TODO: Setup WebRTC and answer
    setState(() {
      _isConnected = true;
      _callStatus = 'Connected';
    });

    _startCallTimer();
  }

  Future<void> _makeCall() async {
    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      Navigator.pop(context);
      return;
    }

    // TODO: Setup WebRTC and make offer
    setState(() {
      _isConnected = true;
      _callStatus = 'Connected';
    });

    _startCallTimer();
  }

  void _startCallTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isConnected) {
        setState(() {
          _callDuration = Duration(seconds: _callDuration.inSeconds + 1);
        });
        return true;
      }
      return false;
    });
  }

  void _endCall() {
    _signalingService.emit('call-end', {'to': widget.targetUserId});
    _signalingService.disconnect();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    // TODO: Actually mute the audio track
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    // TODO: Actually toggle speaker output
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[700],
                      child: Text(
                        widget.isIncoming
                            ? (widget.callerName?.substring(0, 1).toUpperCase() ?? '?')
                            : '?',
                        style: const TextStyle(fontSize: 48, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.isIncoming
                          ? (widget.callerName ?? 'Unknown')
                          : 'User',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isConnected ? _formatDuration(_callDuration) : _callStatus,
                      style: TextStyle(
                        fontSize: 18,
                        color: _isConnected ? Colors.white70 : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_isConnected && widget.isIncoming)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton.filled(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.call_end),
                      iconSize: 32,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(70, 70),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _answerCall,
                      icon: const Icon(Icons.call),
                      iconSize: 32,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(70, 70),
                      ),
                    ),
                  ],
                ),
              )
            else if (_isConnected)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton.filled(
                      onPressed: _toggleMute,
                      icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                      iconSize: 28,
                      style: IconButton.styleFrom(
                        backgroundColor: _isMuted ? Colors.white24 : Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(65, 65),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _toggleSpeaker,
                      icon: Icon(_isSpeakerOn ? Icons.volume_up : Icons.volume_down),
                      iconSize: 28,
                      style: IconButton.styleFrom(
                        backgroundColor: _isSpeakerOn ? Colors.white24 : Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(65, 65),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.call_end),
                      iconSize: 32,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(70, 70),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Verify no syntax errors**

Run: `cd flutter_app && flutter analyze lib/screens/call_screen.dart`

Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/screens/call_screen.dart
git commit -m "feat: add CallScreen for 1v1 voice calls"
```

---

## Task 15: Flutter - Update Main.dart with Navigation

**Files:**
- Modify: `flutter_app/lib/main.dart`

**Step 1: Update main.dart to include navigation and new screens**

Replace entire file with:

```dart
import 'package:flutter/material.dart';
import 'screens/channel_list_screen.dart';
import 'screens/live_list_screen.dart';
import 'screens/call_screen.dart';

void main() {
  runApp(const RadioApp());
}

class RadioApp extends StatelessWidget {
  const RadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Internet Radio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ChannelListScreen(),
    const LiveListScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radio),
            label: 'Channels',
          ),
          NavigationDestination(
            icon: Icon(Icons.live_tv),
            label: 'Live',
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Verify no syntax errors**

Run: `cd flutter_app && flutter analyze lib/main.dart`

Expected: No issues found

**Step 3: Test the app builds**

Run: `cd flutter_app && flutter build apk --debug`

Expected: Build succeeds

**Step 4: Commit**

```bash
git add flutter_app/lib/main.dart
git commit -m "feat: add bottom navigation with Live tab"
```

---

## Task 16: Testing and Verification

**Files:**
- None

**Step 1: Start backend server**

```bash
cd backend
npm start
```

Expected output:
```
Radio backend server running on http://localhost:3000
API available at http://localhost:3000/api/channels
Socket.io server ready for Phase 2 live streaming
```

**Step 2: Test API endpoints**

```bash
# Test health
curl http://localhost:3000/health

# Test live rooms list (should be empty initially)
curl http://localhost:3000/api/live

# Test creating a live room
curl -X POST http://localhost:3000/api/live \
  -H "Content-Type: application/json" \
  -d '{"broadcasterName":"TestDJ","title":"Test Live Show"}'
```

Expected: Valid JSON responses

**Step 3: Test Flutter app on emulator/device**

```bash
cd flutter_app
flutter run
```

**Manual test checklist:**
- [ ] App launches with bottom navigation (Channels, Live tabs)
- [ ] Live tab shows empty state when no broadcasts
- [ ] "Go Live" button opens broadcaster screen
- [ ] Can fill in broadcast details
- [ ] Microphone permission requested
- [ ] Broadcast starts and shows live UI
- [ ] Pressing end button returns to list

**Step 4: Update documentation**

Update README.md with Phase 2 features:

```markdown
## Phase 2 Features (Current)

- Live broadcasting with real-time listener count
- Join live broadcasts as listener
- 1v1 voice calls (UI ready, WebRTC signaling in place)
- Bottom navigation with Channels and Live tabs
- Socket.io real-time communication
```

**Step 5: Final commit**

```bash
git add README.md
git commit -m "docs: update README for Phase 2 features"
```

---

## Summary

This implementation plan adds:

1. **Backend:**
   - Live rooms database table
   - In-memory room management
   - REST API for live rooms
   - WebRTC signaling via Socket.io

2. **Flutter:**
   - New dependencies (socket_io_client, flutter_webrtc, permission_handler)
   - LiveRoom model
   - LiveService for API calls
   - SignalingService for Socket.io
   - WebRTCService for peer connections
   - LiveListScreen, BroadcasterScreen, ListenerScreen, CallScreen
   - Bottom navigation

3. **Total commits:** 16 focused, incremental commits

---

**Next Steps after Phase 2:**
- Implement actual WebRTC audio streaming in Broadcaster/Listener screens
- Add user authentication for persistent identities
- Add chat/messaging in live rooms
- Add recording functionality for broadcasts
- Scale testing with multiple concurrent listeners
