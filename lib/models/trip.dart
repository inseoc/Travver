import 'package:equatable/equatable.dart';
import 'daily_plan.dart';
import 'location.dart';

/// 여행 상태
enum TripStatus {
  upcoming,  // 예정
  ongoing,   // 진행중
  completed, // 완료
}

/// 여행 기간
class TripPeriod extends Equatable {
  final DateTime start;
  final DateTime end;

  const TripPeriod({
    required this.start,
    required this.end,
  });

  /// 여행 일수
  int get days => end.difference(start).inDays + 1;

  /// 기간 문자열 (예: "2026.03.01 ~ 2026.03.04")
  String get displayString {
    final startStr = '${start.year}.${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')}';
    final endStr = '${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';
    return '$startStr ~ $endStr';
  }

  factory TripPeriod.fromJson(Map<String, dynamic> json) {
    return TripPeriod(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start.toIso8601String().split('T')[0],
      'end': end.toIso8601String().split('T')[0],
    };
  }

  @override
  List<Object?> get props => [start, end];
}

/// 예산 정보
class Budget extends Equatable {
  final int estimated;
  final String currency;

  const Budget({
    required this.estimated,
    this.currency = 'KRW',
  });

  /// 예산 문자열 (예: "850,000원")
  String get displayString {
    final formatted = estimated.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return currency == 'KRW' ? '$formatted원' : '$formatted $currency';
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      estimated: json['estimated'] as int,
      currency: json['currency'] as String? ?? 'KRW',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'estimated': estimated,
      'currency': currency,
    };
  }

  @override
  List<Object?> get props => [estimated, currency];
}

/// 여행 스타일
enum TravelStyle {
  food('맛집 탐방', 'restaurant'),
  sightseeing('관광 명소', 'place'),
  relaxation('휴양', 'spa'),
  activity('액티비티', 'sports'),
  shopping('쇼핑', 'shopping_bag'),
  photo('사진 명소', 'camera_alt');

  final String label;
  final String iconName;

  const TravelStyle(this.label, this.iconName);

  static TravelStyle fromString(String value) {
    return TravelStyle.values.firstWhere(
      (style) => style.name == value || style.label == value,
      orElse: () => TravelStyle.sightseeing,
    );
  }
}

/// 여행 정보 모델
class Trip extends Equatable {
  final String id;
  final String destination;
  final TripPeriod period;
  final int travelers;
  final Budget budget;
  final List<TravelStyle> styles;
  final String? customPreference; // 사용자 정의 여행 선호도
  final String? accommodationLocation; // 숙소 위치
  final List<DailyPlan> dailyPlans;
  TripStatus status;
  final DateTime createdAt;
  final String? imageUrl;

  Trip({
    required this.id,
    required this.destination,
    required this.period,
    required this.travelers,
    required this.budget,
    required this.styles,
    this.customPreference,
    this.accommodationLocation,
    this.dailyPlans = const [],
    this.status = TripStatus.upcoming,
    DateTime? createdAt,
    this.imageUrl,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 총 일정 수
  int get totalSchedules =>
      dailyPlans.fold(0, (sum, day) => sum + day.schedules.length);

  /// 모든 장소의 좌표 리스트
  List<Location> get allLocations {
    return dailyPlans
        .expand((day) => day.schedules.map((s) => s.location))
        .toList();
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      destination: json['destination'] as String,
      period: TripPeriod.fromJson(json['period'] as Map<String, dynamic>),
      travelers: json['travelers'] as int? ?? 1,
      budget: Budget.fromJson(json['total_budget'] as Map<String, dynamic>),
      styles: (json['styles'] as List<dynamic>?)
              ?.map((s) => TravelStyle.fromString(s as String))
              .toList() ??
          [],
      customPreference: json['custom_preference'] as String?,
      accommodationLocation: json['accommodation_location'] as String?,
      dailyPlans: (json['daily_plans'] as List<dynamic>?)
              ?.map((d) => DailyPlan.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      status: TripStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TripStatus.upcoming,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination': destination,
      'period': period.toJson(),
      'travelers': travelers,
      'total_budget': budget.toJson(),
      'styles': styles.map((s) => s.name).toList(),
      'custom_preference': customPreference,
      'accommodation_location': accommodationLocation,
      'daily_plans': dailyPlans.map((d) => d.toJson()).toList(),
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'image_url': imageUrl,
    };
  }

  Trip copyWith({
    String? id,
    String? destination,
    TripPeriod? period,
    int? travelers,
    Budget? budget,
    List<TravelStyle>? styles,
    String? customPreference,
    String? accommodationLocation,
    List<DailyPlan>? dailyPlans,
    TripStatus? status,
    DateTime? createdAt,
    String? imageUrl,
  }) {
    return Trip(
      id: id ?? this.id,
      destination: destination ?? this.destination,
      period: period ?? this.period,
      travelers: travelers ?? this.travelers,
      budget: budget ?? this.budget,
      styles: styles ?? this.styles,
      customPreference: customPreference ?? this.customPreference,
      accommodationLocation: accommodationLocation ?? this.accommodationLocation,
      dailyPlans: dailyPlans ?? this.dailyPlans,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        destination,
        period,
        travelers,
        budget,
        styles,
        customPreference,
        accommodationLocation,
        dailyPlans,
        status,
        createdAt,
        imageUrl,
      ];
}
