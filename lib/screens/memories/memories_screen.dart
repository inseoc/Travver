import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';

/// 추억 남기기 화면
/// - 여행 시작일 <= 오늘인 여행 목록을 보여주고, 선택하면 사진/영상 기능 접근
class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final eligibleTrips = tripProvider.memoryEligibleTrips;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('추억 남기기', style: AppTypography.subhead1),
      ),
      body: eligibleTrips.isEmpty
          ? _buildEmptyState()
          : _buildTripList(context, eligibleTrips),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.luggage_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: AppDimens.spacing16),
            Text(
              '추억 남길 수 있는 여행이 없어요',
              style: AppTypography.subhead2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spacing8),
            Text(
              '여행 시작일이 되면 여기에 나타나요',
              style: AppTypography.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripList(BuildContext context, List<Trip> trips) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '추억 남길 수 있는 여행 목록',
            style: AppTypography.subhead2,
          ),
          const SizedBox(height: AppDimens.spacing4),
          Text(
            '여행을 선택해 특별한 추억을 만들어보세요',
            style: AppTypography.body2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spacing16),
          ...trips.map((trip) => Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spacing12),
            child: _buildTripCard(context, trip),
          )),
        ],
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(trip.period.start.year, trip.period.start.month, trip.period.start.day);
    final isToday = start.isAtSameMomentAs(today);

    return GestureDetector(
      onTap: () => _showTripActions(context, trip),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimens.spacing16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              ),
              child: Icon(
                Icons.flight_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppDimens.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          trip.destination,
                          style: AppTypography.subhead2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: AppDimens.spacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '오늘 출발',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppDimens.spacing4),
                  Text(
                    trip.period.displayString,
                    style: AppTypography.body2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showTripActions(BuildContext context, Trip trip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLarge),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spacing20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${trip.destination} 추억 만들기',
                style: AppTypography.subhead1,
              ),
              Text(
                trip.period.displayString,
                style: AppTypography.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimens.spacing20),
              _buildActionTile(
                context: context,
                icon: Icons.photo_camera_outlined,
                title: '사진 꾸미기',
                description: 'AI로 여행 사진을 예술적으로 꾸며보세요',
                color: AppColors.accent,
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.photoDecorator, extra: trip.id);
                },
              ),
              const SizedBox(height: AppDimens.spacing12),
              _buildActionTile(
                context: context,
                icon: Icons.videocam_outlined,
                title: '나만의 영상',
                description: 'AI로 시네마틱 여행 영상을 만들어보세요',
                color: AppColors.info,
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.videoCreator, extra: trip.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimens.spacing16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: AppDimens.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.subhead2),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
