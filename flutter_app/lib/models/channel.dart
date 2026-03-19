class Channel {
  final String id;
  final String name;
  final String description;
  final String url;
  final String genre;
  final String? imageUrl;

  const Channel({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.genre,
    this.imageUrl,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      url: json['url'] as String? ?? '',
      genre: json['genre'] as String? ?? 'Other',
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'url': url,
      'genre': genre,
      'imageUrl': imageUrl,
    };
  }
}
