class LiveRoom {
  final String id;
  final String broadcasterName;
  final String title;
  final String? description;
  final String? genre;
  final int listenerCount;
  final bool isLive;
  final String createdAt;
  final String? broadcasterSocketId;

  LiveRoom({
    required this.id,
    required this.broadcasterName,
    required this.title,
    this.description,
    this.genre,
    required this.listenerCount,
    required this.isLive,
    required this.createdAt,
    this.broadcasterSocketId,
  });

  factory LiveRoom.fromJson(Map<String, dynamic> json) {
    return LiveRoom(
      id: json['id'] ?? '',
      broadcasterName: json['broadcaster_name'] ?? json['broadcasterName'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      genre: json['genre'],
      listenerCount: json['listener_count'] ?? json['listenerCount'] ?? 0,
      isLive: json['is_live'] ?? json['isLive'] ?? false,
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
      broadcasterSocketId: json['broadcaster_socket_id'] ?? json['broadcasterSocketId'],
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
      'broadcasterSocketId': broadcasterSocketId,
    };
  }
}
