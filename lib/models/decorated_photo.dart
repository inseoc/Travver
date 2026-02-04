/// 꾸며진 사진 모델
class DecoratedPhoto {
  final String id;
  final String tripId;
  final String originalFilename;
  final String style;
  final String resultImageBase64;
  final String resultMimeType;
  final DateTime createdAt;

  DecoratedPhoto({
    required this.id,
    required this.tripId,
    required this.originalFilename,
    required this.style,
    required this.resultImageBase64,
    this.resultMimeType = 'image/jpeg',
    required this.createdAt,
  });

  factory DecoratedPhoto.fromJson(Map<String, dynamic> json) {
    return DecoratedPhoto(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      originalFilename: json['original_filename'] as String,
      style: json['style'] as String,
      resultImageBase64: json['result_image_base64'] as String,
      resultMimeType: json['result_mime_type'] as String? ?? 'image/jpeg',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trip_id': tripId,
        'original_filename': originalFilename,
        'style': style,
        'result_image_base64': resultImageBase64,
        'result_mime_type': resultMimeType,
        'created_at': createdAt.toIso8601String(),
      };

  String get styleLabel {
    const labels = {
      'watercolor': '수채화',
      'oil_painting': '유화',
      'sketch': '스케치',
      'vintage': '빈티지',
      'movie_poster': '영화 포스터',
      'pop_art': '팝아트',
    };
    return labels[style] ?? style;
  }
}
