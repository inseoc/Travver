import 'package:equatable/equatable.dart';
import 'schedule.dart';

/// 일일 계획 모델
class DailyPlan extends Equatable {
  final int day;
  final DateTime date;
  final String theme;
  final List<Schedule> schedules;

  const DailyPlan({
    required this.day,
    required this.date,
    required this.theme,
    this.schedules = const [],
  });

  /// 당일 총 예상 비용
  int get totalCost => schedules.fold(0, (sum, s) => sum + s.estimatedCost);

  /// 당일 총 소요 시간 (분)
  int get totalDuration => schedules.fold(0, (sum, s) => sum + s.durationMin);

  /// 날짜 문자열 (예: "3월 1일 (토)")
  String get dateString {
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.month}월 ${date.day}일 ($weekday)';
  }

  factory DailyPlan.fromJson(Map<String, dynamic> json) {
    return DailyPlan(
      day: json['day'] as int,
      date: DateTime.parse(json['date'] as String),
      theme: json['theme'] as String? ?? '',
      schedules: (json['schedules'] as List<dynamic>?)
              ?.map((s) => Schedule.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'date': date.toIso8601String().split('T')[0],
      'theme': theme,
      'schedules': schedules.map((s) => s.toJson()).toList(),
    };
  }

  DailyPlan copyWith({
    int? day,
    DateTime? date,
    String? theme,
    List<Schedule>? schedules,
  }) {
    return DailyPlan(
      day: day ?? this.day,
      date: date ?? this.date,
      theme: theme ?? this.theme,
      schedules: schedules ?? this.schedules,
    );
  }

  @override
  List<Object?> get props => [day, date, theme, schedules];
}
