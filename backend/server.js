import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { Server } from 'socket.io';
import Database from 'better-sqlite3';

const app = express();
const PORT = 3000;

// Create HTTP server for Socket.io
const httpServer = createServer(app);

// Initialize Socket.io
const io = new Server(httpServer, {
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
    methods: ['GET', 'POST']
  }
});

// Configure CORS
const allowedOrigins = (process.env.CORS_ORIGIN || '*').split(',');

// Middleware
app.use(cors({
  origin: (origin, callback) => {
    if (allowedOrigins.includes('*') || !origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  methods: ['GET', 'POST', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(express.json({ strict: true, limit: '1mb' }));

// Validate JSON content type for POST/PUT/PATCH
app.use((req, res, next) => {
  if (['POST', 'PUT', 'PATCH'].includes(req.method) && !req.is('application/json')) {
    return res.status(415).json({ error: 'Content-Type must be application/json' });
  }
  next();
});

// Request logging
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.path} ${res.statusCode} ${duration}ms`);
  });
  next();
});

// Initialize SQLite database with error handling
const db = new Database('radio.db', { verbose: console.log });

// Enable WAL mode for better concurrent access
db.pragma('journal_mode = WAL');

// Create channels table if not exists
db.exec(`
  CREATE TABLE IF NOT EXISTS channels (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    url TEXT NOT NULL,
    genre TEXT NOT NULL,
    imageUrl TEXT
  )
`);

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

// Seed initial channels if table is empty
const channelCount = db.prepare('SELECT COUNT(*) as count FROM channels').get();
if (channelCount.count === 0) {
  const insertChannel = db.prepare(`
    INSERT INTO channels (id, name, description, url, genre, imageUrl)
    VALUES (?, ?, ?, ?, ?, ?)
  `);

  const channels = [
    {
      id: '1',
      name: 'BBC World Service',
      description: 'International news and analysis from the BBC',
      url: 'https://stream.live.vc.bbcmedia.co.uk/bbc_world_service',
      genre: 'News',
      imageUrl: null
    },
    {
      id: '2',
      name: 'NPR News',
      description: 'National Public Radio - breaking news and analysis',
      url: 'https://npr-ice.streamguys1.com/live.mp3',
      genre: 'News',
      imageUrl: null
    },
    {
      id: '3',
      name: 'Classic FM',
      description: 'The UK\'s favourite classical music station',
      url: 'https://media-ice.musicradio.com/ClassicFMMP3',
      genre: 'Classical',
      imageUrl: null
    },
    {
      id: '4',
      name: 'Jazz FM',
      description: 'The home of smooth jazz and soul',
      url: 'https://edge-bauerall-01-gos2.sharp-stream.com/jazz.mp3',
      genre: 'Jazz',
      imageUrl: null
    },
    {
      id: '5',
      name: 'KEXP',
      description: 'Seattle\'s premier independent music station',
      url: 'https://kexp-mp3-128.streamguys1.com/kexp128.mp3',
      genre: 'Alternative',
      imageUrl: null
    }
  ];

  const insertMany = db.transaction((channels) => {
    for (const channel of channels) {
      insertChannel.run(channel.id, channel.name, channel.description, channel.url, channel.genre, channel.imageUrl);
    }
  });

  insertMany(channels);
  console.log('Database seeded with initial channels');
}

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

// API Routes

// GET /api/channels - Get all channels
app.get('/api/channels', (req, res) => {
  try {
    const channels = db.prepare('SELECT * FROM channels ORDER BY name').all();
    res.json(channels);
  } catch (error) {
    console.error('Error fetching channels:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/channels/:id - Get a specific channel
app.get('/api/channels/:id', (req, res) => {
  try {
    const channel = db.prepare('SELECT * FROM channels WHERE id = ?').get(req.params.id);
    if (!channel) {
      return res.status(404).json({ error: 'Channel not found' });
    }
    res.json(channel);
  } catch (error) {
    console.error('Error fetching channel:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Validate URL format
function isValidUrl(string) {
  try {
    const url = new URL(string);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch (_) {
    return false;
  }
}

// Sanitize string input
function sanitize(input) {
  if (typeof input !== 'string') return input;
  return input.trim().slice(0, 500);
}

// POST /api/channels - Add a new channel (admin function)
// TODO: Add authentication middleware to protect this endpoint
app.post('/api/channels', (req, res) => {
  try {
    let { id, name, description, url, genre, imageUrl } = req.body;

    // Validate required fields
    if (!id || !name || !description || !url || !genre) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Sanitize inputs
    id = sanitize(id);
    name = sanitize(name);
    description = sanitize(description);
    genre = sanitize(genre);
    url = sanitize(url);
    imageUrl = imageUrl ? sanitize(imageUrl) : null;

    // Validate sanitized inputs aren't empty
    if (!id || !name || !description || !url || !genre) {
      return res.status(400).json({ error: 'Fields cannot be empty or just whitespace' });
    }

    // Additional length validation
    if (id.length > 50) return res.status(400).json({ error: 'ID too long (max 50 characters)' });
    if (name.length > 200) return res.status(400).json({ error: 'Name too long (max 200 characters)' });
    if (description.length > 1000) return res.status(400).json({ error: 'Description too long (max 1000 characters)' });
    if (genre.length > 50) return res.status(400).json({ error: 'Genre too long (max 50 characters)' });

    // Validate URL format
    if (!isValidUrl(url)) {
      return res.status(400).json({ error: 'Invalid URL format' });
    }

    // Validate imageUrl if provided
    if (imageUrl && !isValidUrl(imageUrl)) {
      return res.status(400).json({ error: 'Invalid imageUrl format' });
    }

    // Validate genre against allowed values
    const allowedGenres = ['News', 'Classical', 'Jazz', 'Alternative', 'Electronic', 'Pop', 'Rock', 'Lo-fi'];
    if (!allowedGenres.includes(genre)) {
      return res.status(400).json({ error: 'Invalid genre' });
    }

    const insertChannel = db.prepare(`
      INSERT INTO channels (id, name, description, url, genre, imageUrl)
      VALUES (?, ?, ?, ?, ?, ?)
    `);

    insertChannel.run(id, name, description, url, genre, imageUrl || null);
    res.status(201).json({ message: 'Channel created successfully' });
  } catch (error) {
    if (error.code === 'SQLITE_CONSTRAINT_PRIMARYKEY') {
      return res.status(409).json({ error: 'Channel ID already exists' });
    }
    console.error('Error creating channel:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /api/channels/:id - Delete a channel (admin function)
// TODO: Add authentication middleware to protect this endpoint
app.delete('/api/channels/:id', (req, res) => {
  try {
    // Validate ID format
    const id = req.params.id;
    if (!id || id.length > 50) {
      return res.status(400).json({ error: 'Invalid channel ID' });
    }

    const result = db.prepare('DELETE FROM channels WHERE id = ?').run(id);
    if (result.changes === 0) {
      return res.status(404).json({ error: 'Channel not found' });
    }
    res.json({ message: 'Channel deleted successfully' });
  } catch (error) {
    console.error('Error deleting channel:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

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

// Health check endpoint
app.get('/health', (req, res) => {
  const liveRoomCount = getAllLiveRooms().length;
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    liveRooms: liveRoomCount
  });
});

// Start server
httpServer.listen(PORT, () => {
  console.log(`Radio backend server running on http://localhost:${PORT}`);
  console.log(`API available at http://localhost:${PORT}/api/channels`);
  console.log(`Socket.io server ready for Phase 2 live streaming`);
});

// Graceful shutdown
const gracefulShutdown = (signal) => {
  console.log(`\nReceived ${signal}, shutting down gracefully...`);
  db.close();
  httpServer.close(() => {
    console.log('Server closed');
    process.exit(0);
  });

  // Force shutdown after 10 seconds
  setTimeout(() => {
    console.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
};

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err);
  gracefulShutdown('uncaughtException');
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled rejection at:', promise, 'reason:', reason);
  gracefulShutdown('unhandledRejection');
});
