# Phase 2: Live Streaming & 1v1 Voice Calls Design

**Date**: 2026-03-19
**Status**: Approved

## Overview

Phase 2 adds real-time live broadcasting and 1v1 voice calls to the radio app using WebRTC for ultra-low latency audio communication.

## Technology Choice: WebRTC-based (Approach 1)

Selected for lowest latency and true real-time communication, which is what users expect from "live" features.

## Architecture

### Backend

#### New Dependencies
- `node-media-server`: HLS streaming fallback (optional)
- Existing `socket.io` will handle WebRTC signaling

#### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/live` | Create a new live broadcast room |
| GET | `/api/live` | List all active live rooms |
| GET | `/api/live/:roomId` | Get details of a specific room |
| DELETE | `/api/live/:roomId` | End a live broadcast |
| POST | `/api/call/offer` | Initiate 1v1 call offer |
| POST | `/api/call/answer` | Answer a 1v1 call |
| POST | `/api/call/ice` | Exchange ICE candidates |

#### Database Schema

```sql
CREATE TABLE live_rooms (
  id TEXT PRIMARY KEY,
  broadcaster_name TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  genre TEXT,
  listener_count INTEGER DEFAULT 0,
  is_live BOOLEAN DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE calls (
  id TEXT PRIMARY KEY,
  caller_id TEXT NOT NULL,
  callee_id TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Socket.io Events

**Live Streaming:**
- `create-room` - Client requests to create live room
- `join-room` - Listener joins a live room
- `leave-room` - Listener leaves room
- `room-updated` - Server broadcasts room updates (listener count)

**WebRTC Signaling:**
- `signal` - Exchange WebRTC signals (offer, answer, ICE)
- `call-offer` - Incoming call offer
- `call-answer` - Call answer response
- `call-end` - Terminate call

### Flutter App

#### New Dependencies

```yaml
dependencies:
  socket_io_client: ^2.0.0
  flutter_webrtc: ^0.9.47
  permission_handler: ^11.0.0
```

#### New Screens

1. **LiveListScreen** - Browse and join active live broadcasts
2. **BroadcasterScreen** - Broadcast live audio (with mic control)
3. **ListenerScreen** - Listen to live broadcast with chat
4. **CallScreen** - 1v1 voice call UI

#### New Services

1. **LiveService** - API calls for live room management
2. **WebRTCService** - WebRTC peer connection management
3. **SignalingService** - Socket.io signaling handler

#### Navigation Structure

```
Main App
├── ChannelListScreen (Phase 1)
├── PlayerScreen (Phase 1)
├── LiveListScreen (NEW - Tab/Navigation)
├── BroadcasterScreen (NEW - from LiveList)
├── ListenerScreen (NEW - from LiveList)
└── CallScreen (NEW - overlay)
```

## Data Flow

### Live Broadcasting Flow

1. **Broadcaster**:
   - Creates room via API → receives roomId
   - Initializes WebRTC peer connection
   - Captures audio from microphone
   - Sends offer to signaling server

2. **Listener**:
   - Discovers room via `/api/live` list
   - Joins room via Socket.io
   - Receives offer via signaling
   - Creates peer connection and answers
   - Plays incoming audio stream

3. **Server**:
   - Tracks active rooms in memory + database
   - Forwards WebRTC signals between peers
   - Broadcasts listener count updates

### 1v1 Call Flow

1. Caller initiates call → sends offer via Socket.io
2. Callee receives call notification → accepts or declines
3. If accepted: callee sends answer back
4. ICE candidates exchanged directly via signaling
5. Direct P2P audio connection established
6. Either party can end call

## Error Handling

- **Network failures**: Graceful reconnection attempts
- **Permission denied**: Clear user prompts for microphone access
- **Room not found**: Return to live list with error message
- **Call declined**: Show notification to caller
- **Connection timeout**: Retry with backoff

## Security Considerations

- Sanitize all room titles and descriptions
- Rate limit room creation (1 per minute per user)
- Optional: Add authentication tokens (Phase 3)
- Validate all WebRTC signals

## Testing Strategy

- Unit tests for API endpoints
- Integration tests for Socket.io signaling
- Manual testing on multiple devices for audio quality
- Test with 10+ concurrent listeners
