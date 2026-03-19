# Internet Radio App

A cross-platform internet radio app with live broadcasting and 1v1 call features, built with Flutter and Node.js.

## Features

### Phase 1: Radio Player
- Browse internet radio channels by genre
- Play streaming audio directly in the app
- Volume control and playback management
- Material Design 3 UI
- 5 preset radio stations

### Phase 2: Live Broadcasting & Calls
- **Go Live**: Create your own live broadcast room
- **Join Live**: Listen to live broadcasts
- **1v1 Calls**: Request to connect with broadcasters
- **Call Controls**: 
  - Broadcaster can accept/reject call requests
  - Set time limits for calls (1/3/5 min or unlimited)
  - End calls at any time
- **Real-time Listener Count**

## Architecture

```
radio-app/
├── flutter_app/              # Flutter mobile/desktop app
│   ├── lib/
│   │   ├── main.dart         # App entry with bottom navigation
│   │   ├── models/
│   │   │   ├── channel.dart  # Radio channel model
│   │   │   └── live_room.dart # Live room model
│   │   ├── screens/
│   │   │   ├── channel_list_screen.dart  # Radio channels list
│   │   │   ├── player_screen.dart        # Audio player
│   │   │   ├── live_list_screen.dart     # Live broadcasts list
│   │   │   ├── broadcaster_screen.dart   # Broadcaster control panel
│   │   │   └── listener_live_screen.dart # Listener view
│   │   └── services/
│   │       ├── channel_service.dart  # Radio API
│   │       ├── live_service.dart     # Live room API
│   │       ├── socket_service.dart   # Socket.io client
│   │       └── webrtc_service.dart   # WebRTC calls
│   └── pubspec.yaml
└── backend/                  # Node.js Express API
    ├── server.js             # Express + Socket.io server
    ├── package.json
    └── radio.db              # SQLite database (auto-created)
```

## Quick Start

### Backend Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Start the server:
```bash
npm start
```

The API will be available at `http://localhost:3000`

### Flutter App Setup

1. Navigate to the Flutter app directory:
```bash
cd flutter_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Running on Different Platforms

### Android Emulator
The app is configured to use `10.0.2.2:3000` for connecting to localhost. No changes needed.

### iOS Simulator
Change the base URL in `channel_service.dart` and `socket_service.dart` from `10.0.2.2` to `localhost`.

### Real Devices
Change the base URL to your computer's IP address (e.g., `192.168.1.100:3000`).

### Web
Change the base URL to `localhost:3000`.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/channels` | Get all radio channels |
| GET | `/api/channels/:id` | Get a specific channel |
| POST | `/api/channels` | Add a new channel |
| DELETE | `/api/channels/:id` | Delete a channel |

## Socket.io Events

### Client → Server
| Event | Description |
|-------|-------------|
| `create-room` | Create a live broadcast room |
| `join-room` | Join a live room as listener |
| `leave-room` | Leave a live room |
| `end-room` | End a broadcast (broadcaster only) |
| `call-offer` | Send WebRTC call offer |
| `call-answer` | Send WebRTC call answer |
| `call-ice` | Send ICE candidate |
| `call-end` | End a call |

### Server → Client
| Event | Description |
|-------|-------------|
| `room-created` | Room creation confirmation |
| `rooms-updated` | Live rooms list updated |
| `room-joined` | Successfully joined room |
| `listener-updated` | Listener count changed |
| `room-ended` | Broadcast has ended |
| `incoming-call` | Incoming call request |
| `call-answered` | Call was answered |
| `call-ice` | ICE candidate received |
| `call-ended` | Call was ended |

## Default Radio Stations

1. **BBC World Service** - International news and analysis
2. **NPR News** - National Public Radio breaking news
3. **Classic FM** - The UK's favourite classical music
4. **Jazz FM** - Smooth jazz and soul
5. **KEXP** - Seattle's premier independent music

## Tech Stack

### Frontend
- Flutter 3.x
- `audioplayers` - Audio streaming
- `http` - API requests
- `socket_io_client` - Real-time communication
- `flutter_webrtc` - Voice calls
- `permission_handler` - Microphone permissions
- Material Design 3

### Backend
- Node.js
- Express - RESTful API
- better-sqlite3 - SQLite database
- Socket.io - Real-time communication

## Troubleshooting

### Backend won't start
- Ensure Node.js is installed: `node --version`
- Check if port 3000 is already in use
- Delete `radio.db` and restart to reinitialize the database

### Flutter app can't connect to backend
- Make sure the backend server is running
- Check the base URL configuration for your platform
- Ensure CORS is enabled (default in this setup)

### Audio playback issues
- Some streams may take a few seconds to buffer
- Check your internet connection
- Try a different channel

### Call not working
- Grant microphone permission when prompted
- Ensure both parties have stable internet
- WebRTC requires HTTPS in production

## Future Enhancements

- [ ] User authentication
- [ ] Chat during broadcasts
- [ ] Recording broadcasts
- [ ] Push notifications
- [ ] Social features (follow, like)
- [ ] Broadcast scheduling

## License

MIT
