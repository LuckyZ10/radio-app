import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final SocketService _socketService = SocketService();

  // Callbacks
  Function(MediaStream)? onRemoteStream;
  Function()? onCallEnded;
  Function(String)? onError;

  // Configuration for STUN/TURN servers
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  Future<void> initialize() async {
    // Get local audio stream
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
    } catch (e) {
      onError?.call('Failed to get local audio: $e');
      rethrow;
    }
  }

  Future<void> createCall(String targetSocketId, String callerName) async {
    try {
      await _createPeerConnection();

      // Create offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Send offer via socket
      _socketService.sendCallOffer(targetSocketId, offer.toMap(), callerName);
    } catch (e) {
      onError?.call('Failed to create call: $e');
      rethrow;
    }
  }

  Future<void> answerCall(String targetSocketId, dynamic offer) async {
    try {
      await _createPeerConnection();

      // Set remote description (offer from caller)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );

      // Create and set local description (answer)
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer via socket
      _socketService.sendCallAnswer(targetSocketId, answer.toMap());
    } catch (e) {
      onError?.call('Failed to answer call: $e');
      rethrow;
    }
  }

  Future<void> handleAnswer(dynamic answer) async {
    try {
      await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
    } catch (e) {
      onError?.call('Failed to handle answer: $e');
    }
  }

  Future<void> handleIceCandidate(dynamic candidate) async {
    try {
      await _peerConnection?.addCandidate(
        RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMlineIndex'],
        ),
      );
    } catch (e) {
      onError?.call('Failed to handle ICE candidate: $e');
    }
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    // Add local stream
    if (_localStream != null) {
      _peerConnection!.addStream(_localStream!);
    }

    // Handle remote stream
    _peerConnection!.onAddStream = (stream) {
      onRemoteStream?.call(stream);
    };

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (candidate) {
      // Send ICE candidate via socket
      // Note: In a real app, you'd get the target socket ID from the call state
      // This is a simplified version
    };

    // Handle connection state changes
    _peerConnection!.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        endCall();
      }
    };
  }

  void endCall() {
    _peerConnection?.close();
    _peerConnection = null;
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    onCallEnded?.call();
  }

  void dispose() {
    endCall();
  }
}
