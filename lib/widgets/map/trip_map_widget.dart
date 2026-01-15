import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import 'place_marker.dart';
import 'route_polyline.dart';

/// 여행 지도 위젯
/// - flutter_map + Mapbox 스타일
/// - 마커 + 직선 경로 표시
class TripMapWidget extends StatefulWidget {
  final List<DailyPlan> dailyPlans;
  final int selectedDay;
  final int? selectedScheduleIndex;
  final Function(int scheduleIndex)? onMarkerTap;

  const TripMapWidget({
    super.key,
    required this.dailyPlans,
    this.selectedDay = 0,
    this.selectedScheduleIndex,
    this.onMarkerTap,
  });

  @override
  State<TripMapWidget> createState() => _TripMapWidgetState();
}

class _TripMapWidgetState extends State<TripMapWidget> {
  final MapController _mapController = MapController();

  List<Schedule> get _allSchedules {
    return widget.dailyPlans.expand((plan) => plan.schedules).toList();
  }

  LatLng? get _centerPoint {
    if (_allSchedules.isEmpty) return null;

    double totalLat = 0;
    double totalLng = 0;

    for (final schedule in _allSchedules) {
      totalLat += schedule.location.lat;
      totalLng += schedule.location.lng;
    }

    return LatLng(
      totalLat / _allSchedules.length,
      totalLng / _allSchedules.length,
    );
  }

  void _fitBounds() {
    if (_allSchedules.isEmpty) return;

    final points = _allSchedules.map((s) => s.location.toLatLng()).toList();

    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_allSchedules.isEmpty || _centerPoint == null) {
      return _buildEmptyMap();
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _centerPoint!,
            initialZoom: 13,
            minZoom: 3,
            maxZoom: 18,
            onMapReady: _fitBounds,
          ),
          children: [
            // 타일 레이어 (OpenStreetMap)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.travver.app',
            ),

            // 경로 폴리라인
            RoutePolylineLayer(
              dailyPlans: widget.dailyPlans,
              selectedDay: widget.selectedDay,
            ),

            // 마커 레이어
            MarkerLayer(
              markers: _buildMarkers(),
            ),
          ],
        ),

        // 상단 컨트롤
        Positioned(
          top: AppDimens.spacing8,
          right: AppDimens.spacing8,
          child: Column(
            children: [
              _buildControlButton(
                icon: Icons.fullscreen,
                onTap: _fitBounds,
                tooltip: '전체보기',
              ),
              const SizedBox(height: AppDimens.spacing4),
              _buildControlButton(
                icon: Icons.add,
                onTap: () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                ),
                tooltip: '확대',
              ),
              const SizedBox(height: AppDimens.spacing4),
              _buildControlButton(
                icon: Icons.remove,
                onTap: () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1,
                ),
                tooltip: '축소',
              ),
            ],
          ),
        ),

        // Day 필터 표시 (선택된 Day가 있을 때)
        if (widget.selectedDay > 0)
          Positioned(
            top: AppDimens.spacing8,
            left: AppDimens.spacing8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacing12,
                vertical: AppDimens.spacing6,
              ),
              decoration: BoxDecoration(
                color: AppColors.getDayColor(widget.selectedDay),
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              ),
              child: Text(
                'Day ${widget.selectedDay}',
                style: AppTypography.body2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyMap() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppDimens.spacing8),
            Text(
              '지도를 표시할 일정이 없습니다',
              style: AppTypography.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    int globalIndex = 0;

    for (final plan in widget.dailyPlans) {
      final dayColor = AppColors.getDayColor(plan.day);

      for (var i = 0; i < plan.schedules.length; i++) {
        final schedule = plan.schedules[i];
        final currentIndex = globalIndex;
        final isSelected = widget.selectedScheduleIndex == currentIndex;

        markers.add(
          Marker(
            point: schedule.location.toLatLng(),
            width: isSelected ? 52 : 40,
            height: isSelected ? 52 : 40,
            child: PlaceMarker(
              order: schedule.order,
              color: dayColor,
              isSelected: isSelected,
              onTap: () => widget.onMarkerTap?.call(currentIndex),
            ),
          ),
        );

        globalIndex++;
      }
    }

    return markers;
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }
}
