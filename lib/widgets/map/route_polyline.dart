import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../app/theme.dart';
import '../../models/models.dart';

/// 경로 폴리라인 레이어
/// - 장소들을 직선으로 연결
/// - Day별 색상 구분
class RoutePolylineLayer extends StatelessWidget {
  final List<DailyPlan> dailyPlans;
  final int selectedDay;

  const RoutePolylineLayer({
    super.key,
    required this.dailyPlans,
    this.selectedDay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return PolylineLayer(
      polylines: _buildPolylines(),
    );
  }

  List<Polyline> _buildPolylines() {
    final polylines = <Polyline>[];

    for (final plan in dailyPlans) {
      if (plan.schedules.length < 2) continue;

      final points = plan.schedules
          .map((s) => LatLng(s.location.lat, s.location.lng))
          .toList();

      final dayColor = AppColors.getDayColor(plan.day);

      polylines.add(
        Polyline(
          points: points,
          color: dayColor.withOpacity(0.8),
          strokeWidth: 3.0,
          isDotted: true,
        ),
      );
    }

    return polylines;
  }
}

/// 점선 패턴 생성을 위한 확장
extension PolylineExtension on Polyline {
  /// 점선 효과를 위한 패턴
  static List<double> get dashPattern => [10, 5];
}
