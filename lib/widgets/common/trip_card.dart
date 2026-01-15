import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/trip.dart';

/// 여행 카드 위젯
class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  final double width;

  const TripCard({
    super.key,
    required this.trip,
    this.onTap,
    this.width = 200,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 영역
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimens.cardRadius),
              ),
              child: Container(
                height: 100,
                width: double.infinity,
                color: _getStatusColor(trip.status).withOpacity(0.15),
                child: trip.imageUrl != null
                    ? Image.network(
                        trip.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),

            // 정보 영역
            Padding(
              padding: const EdgeInsets.all(AppDimens.spacing12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 목적지명 + 상태 뱃지
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trip.destination,
                          style: AppTypography.subhead2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusBadge(trip.status),
                    ],
                  ),
                  const SizedBox(height: AppDimens.spacing4),

                  // 기간
                  Text(
                    trip.period.displayString,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.flight_outlined,
        size: 40,
        color: _getStatusColor(trip.status).withOpacity(0.5),
      ),
    );
  }

  Widget _buildStatusBadge(TripStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacing8,
        vertical: AppDimens.spacing4,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      ),
      child: Text(
        _getStatusLabel(status),
        style: AppTypography.caption.copyWith(
          color: _getStatusColor(status),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.upcoming:
        return AppColors.info;
      case TripStatus.ongoing:
        return AppColors.success;
      case TripStatus.completed:
        return AppColors.textSecondary;
    }
  }

  String _getStatusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.upcoming:
        return '예정';
      case TripStatus.ongoing:
        return '진행중';
      case TripStatus.completed:
        return '완료';
    }
  }
}
