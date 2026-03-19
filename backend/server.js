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

// Middleware
app.use(cors());
app.use(express.json());

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

  // Join a channel room for live listening
  socket.on('join-channel', (channelId) => {
    socket.join(`channel:${channelId}`);
    console.log(`Socket ${socket.id} joined channel: ${channelId}`);
  });

  // Leave a channel room
  socket.on('leave-channel', (channelId) => {
    socket.leave(`channel:${channelId}`);
    console.log(`Socket ${socket.id} left channel: ${channelId}`);
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
  });
});

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

    // Validate URL format
    if (!isValidUrl(url)) {
      return res.status(400).json({ error: 'Invalid URL format' });
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

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Start server
httpServer.listen(PORT, () => {
  console.log(`Radio backend server running on http://localhost:${PORT}`);
  console.log(`API available at http://localhost:${PORT}/api/channels`);
  console.log(`Socket.io server ready for Phase 2 live streaming`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down gracefully...');
  db.close();
  process.exit(0);
});
