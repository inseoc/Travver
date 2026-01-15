import 'package:equatable/equatable.dart';
import 'location.dart';

/// 장소 카테고리
enum PlaceCategory {
  food('맛집', 'restaurant', '🍽️'),
  sightseeing('관광', 'place', '📍'),
  accommodation('숙소', 'hotel', '🏨'),
  activity('액티비티', 'sports', '🎯'),
  shopping('쇼핑', 'shopping_bag', '🛍️'),
  transport('이동', 'directions_car', '🚗'),
  rest('휴식', 'spa', '☕'),
  photo('사진명소', 'camera_alt', '📷');

  final String label;
  final String iconName;
  final String emoji;

  const PlaceCategory(this.label, this.iconName, this.emoji);

  static PlaceCategory fromString(String value) {
    return PlaceCategory.values.firstWhere(
      (cat) => cat.name == value || cat.label == value,
      orElse: () => PlaceCategory.sightseeing,
    );
  }
}

/// 일정 항목 모델
class Schedule extends Equatable {
  final int order;
  final String time;
  final String place;
  final PlaceCategory category;
  final int durationMin;
  final int estimatedCost;
  final String description;
  final Location location;
  final String? imageUrl;
  final double? rating;
  final String? placeId;

  const Schedule({
    required this.order,
    required this.time,
    required this.place,
    required this.category,
    required this.durationMin,
    required this.estimatedCost,
    required this.description,
    required this.location,
    this.imageUrl,
    this.rating,
    this.placeId,
  });

  /// 소요 시간 문자열 (예: "1시간 30분")
  String get durationString {
    final hours = durationMin ~/ 60;
    final mins = durationMin % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}시간 ${mins}분';
    } else if (hours > 0) {
      return '${hours}시간';
    } else {
      return '${mins}분';
    }
  }

  /// 예상 비용 문자열 (예: "15,000원")
  String get costString {
    if (estimatedCost == 0) return '무료';
    final formatted = estimatedCost.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$formatted원';
  }

  /// 종료 시간 계산 (예: "10:00" + 90분 = "11:30")
  String get endTime {
    final parts = time.split(':');
    final startHour = int.parse(parts[0]);
    final startMin = int.parse(parts[1]);
    final totalMins = startHour * 60 + startMin + durationMin;
    final endHour = (totalMins ~/ 60) % 24;
    final endMin = totalMins % 60;
    return '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
  }

  /// 시간 범위 문자열 (예: "10:00 - 11:30")
  String get timeRange => '$time - $endTime';

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      order: json['order'] as int,
      time: json['time'] as String,
      place: json['place'] as String,
      category: PlaceCategory.fromString(json['category'] as String),
      durationMin: json['duration_min'] as int,
      estimatedCost: json['estimated_cost'] as int,
      description: json['description'] as String? ?? '',
      location: Location.fromJson(json['location'] as Map<String, dynamic>),
      imageUrl: json['image_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      placeId: json['place_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'time': time,
      'place': place,
      'category': category.name,
      'duration_min': durationMin,
      'estimated_cost': estimatedCost,
      'description': description,
      'location': location.toJson(),
      'image_url': imageUrl,
      'rating': rating,
      'place_id': placeId,
    };
  }

  Schedule copyWith({
    int? order,
    String? time,
    String? place,
    PlaceCategory? category,
    int? durationMin,
    int? estimatedCost,
    String? description,
    Location? location,
    String? imageUrl,
    double? rating,
    String? placeId,
  }) {
    return Schedule(
      order: order ?? this.order,
      time: time ?? this.time,
      place: place ?? this.place,
      category: category ?? this.category,
      durationMin: durationMin ?? this.durationMin,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      description: description ?? this.description,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      placeId: placeId ?? this.placeId,
    );
  }

  @override
  List<Object?> get props => [
        order,
        time,
        place,
        category,
        durationMin,
        estimatedCost,
        description,
        location,
        imageUrl,
        rating,
        placeId,
      ];
}
