# Internet Radio App

A cross-platform internet radio player built with Flutter and Node.js.

## Features

- Browse internet radio channels by genre
- Play streaming audio directly in the app
- Volume control and playback management
- SQLite database for channel storage
- RESTful API backend

## Architecture

```
radio-app/
├── flutter_app/          # Flutter mobile/desktop app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/       # Data models
│   │   ├── screens/      # UI screens
│   │   └── services/     # API services
│   └── pubspec.yaml
└── backend/              # Node.js Express API
    ├── server.js
    ├── package.json
    └── radio.db          # SQLite database (auto-created)
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

## Available Devices

The Flutter app supports:
- Android
- iOS
- Windows
- macOS
- Linux
- Web

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/channels` | Get all radio channels |
| GET | `/api/channels/:id` | Get a specific channel |
| POST | `/api/channels` | Add a new channel |
| DELETE | `/api/channels/:id` | Delete a channel |

## Default Channels

The app comes with 5 pre-configured radio stations:

1. **BBC World Service** - International news and analysis from the BBC
2. **NPR News** - National Public Radio breaking news and analysis
3. **Classic FM** - The UK's favourite classical music station
4. **Jazz FM** - The home of smooth jazz and soul
5. **KEXP** - Seattle's premier independent music station

## Tech Stack

### Frontend
- Flutter 3.x
- audioplayers - Audio streaming
- http - API requests
- Material Design 3

### Backend
- Node.js
- Express - RESTful API
- better-sqlite3 - SQLite database
- Socket.io - Real-time communication (Phase 2)
- CORS - Cross-origin support

## Troubleshooting

### Backend won't start
- Ensure Node.js is installed: `node --version`
- Check if port 3000 is already in use
- Delete `radio.db` and restart to reinitialize the database

### Flutter app can't connect to backend
- Make sure the backend server is running on port 3000
- Check that CORS is enabled (default in this setup)
- The app will show fallback channels if the backend is unavailable

### Audio playback issues
- Some streams may take a few seconds to buffer
- Check your internet connection
- Try a different channel to isolate stream issues

## Phase 1 Features (Current)

- Channel list with card-based UI
- Audio playback with play/pause/stop controls
- Volume slider
- Genre-based color coding
- Backend API with SQLite storage
- Fallback channels for offline development

## Coming in Phase 2

- Live broadcasting with Socket.io
- User roles (listener/broadcaster)
- Real-time listener count
- Channel search and filtering
