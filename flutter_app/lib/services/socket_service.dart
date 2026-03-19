import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;

  Function(Map<String, dynamic>)? onRoomCreated;
  Function(List<dynamic>)? onRoomsUpdated;
  Function(Map<String, dynamic>)? onRoomJoined;
  Function(Map<String, dynamic>)? onListenerUpdated;
  Function(Map<String, dynamic>)? onRoomEnded;
  Function(Map<String, dynamic>)? onIncomingCall;
  Function(Map<String, dynamic>)? onCallAnswered;
  Function(Map<String, dynamic>)? onCallIce;
  Function(Map<String, dynamic>)? onCallEnded;
  Function(dynamic)? onSignal;
  Function(String)? onError;

  io.Socket? get socket => _socket;
  bool get isConnected => _isConnected;

  void connect(String serverUrl) {
    if (_socket != null && _isConnected) return;

    _socket = io.io(
      serverUrl,
      io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      print('Socket connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('Socket disconnected');
    });

    _socket!.onConnectError((error) {
      print('Socket connection error: $error');
      onError?.call('Connection error: $error');
    });

    _socket!.on('rooms-updated', (data) {
      onRoomsUpdated?.call(List<dynamic>.from(data));
    });

    _socket!.on('room-joined', (data) {
      onRoomJoined?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('listener-updated', (data) {
      onListenerUpdated?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('room-ended', (data) {
      onRoomEnded?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('incoming-call', (data) {
      onIncomingCall?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('call-answered', (data) {
      onCallAnswered?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('call-ice', (data) {
      onCallIce?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('call-ended', (data) {
      onCallEnded?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('signal', (data) {
      onSignal?.call(data);
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void createRoom({
    required String broadcasterName,
    required String title,
    String? description,
    String? genre,
    required Function(Map<String, dynamic>) callback,
  }) {
    _socket?.emitWithAck('create-room', {
      'broadcasterName': broadcasterName,
      'title': title,
      'description': description,
      'genre': genre,
    }, ack: (response) {
      callback(Map<String, dynamic>.from(response));
    });
  }

  void joinRoom(String roomId) {
    _socket?.emit('join-room', {'roomId': roomId});
  }

  void leaveRoom(String roomId) {
    _socket?.emit('leave-room', {'roomId': roomId});
  }

  void endRoom(String roomId, Function(Map<String, dynamic>) callback) {
    _socket?.emitWithAck('end-room', {'roomId': roomId}, ack: (response) {
      callback(Map<String, dynamic>.from(response));
    });
  }

  void sendSignal(String to, dynamic signal, String roomId) {
    _socket?.emit('signal', {'to': to, 'signal': signal, 'roomId': roomId});
  }

  void sendCallOffer(String to, dynamic offer, String callerName) {
    _socket?.emit('call-offer', {'to': to, 'offer': offer, 'callerName': callerName});
  }

  void sendCallAnswer(String to, dynamic answer) {
    _socket?.emit('call-answer', {'to': to, 'answer': answer});
  }

  void sendCallIce(String to, dynamic candidate) {
    _socket?.emit('call-ice', {'to': to, 'candidate': candidate});
  }

  void endCall(String to) {
    _socket?.emit('call-end', {'to': to});
  }
}
