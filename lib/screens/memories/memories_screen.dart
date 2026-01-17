import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';

/// 추억 남기기 화면
/// - 여행 사진/영상을 AI로 특별한 추억으로 변환
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  Trip? _selectedTrip;

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final completedTrips = tripProvider.completedTrips;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('추억 남기기', style: AppTypography.subhead1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 여행 선택 드롭다운
            _buildTripSelector(completedTrips),
            const SizedBox(height: AppDimens.spacing24),

            // 메인 카드들
            _buildFeatureCard(
              icon: Icons.photo_camera_outlined,
              title: '사진 꾸미기',
              description: 'AI로 여행 사진을 예술적으로 꾸며보세요',
              color: AppColors.accent,
              isEnabled: _selectedTrip != null,
              onTap: () {
                if (_selectedTrip == null) {
                  _showTripRequiredMessage();
                  return;
                }
                context.push(
                  AppRoutes.photoDecorator,
                  extra: _selectedTrip!.id,
                );
              },
            ),
            const SizedBox(height: AppDimens.spacing16),
            _buildFeatureCard(
              icon: Icons.videocam_outlined,
              title: '나만의 영상',
              description: 'AI로 시네마틱 여행 영상을 만들어보세요',
              color: AppColors.info,
              isEnabled: _selectedTrip != null,
              onTap: () {
                if (_selectedTrip == null) {
                  _showTripRequiredMessage();
                  return;
                }
                context.push(
                  AppRoutes.videoCreator,
                  extra: _selectedTrip!.id,
                );
              },
            ),
            const SizedBox(height: AppDimens.spacing32),

            // 이전에 만든 추억 갤러리
            _buildPreviousMemories(),
          ],
        ),
      ),
    );
  }

  Widget _buildTripSelector(List<Trip> trips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '어떤 여행의 추억을 만들까요?',
          style: AppTypography.subhead2,
        ),
        const SizedBox(height: AppDimens.spacing12),
        if (trips.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.spacing16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.textSecondary),
                const SizedBox(width: AppDimens.spacing12),
                Expanded(
                  child: Text(
                    '완료된 여행이 있을 때 추억을 만들 수 있어요',
                    style: AppTypography.body2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<Trip>(
            value: _selectedTrip,
            decoration: InputDecoration(
              hintText: '여행 선택',
              prefixIcon: const Icon(Icons.flight_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              ),
            ),
            items: trips.map((trip) {
              return DropdownMenuItem(
                value: trip,
                child: Text('${trip.destination} (${trip.period.displayString})'),
              );
            }).toList(),
            onChanged: (trip) {
              setState(() => _selectedTrip = trip);
            },
          ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimens.spacing20),
        decoration: BoxDecoration(
          color: isEnabled ? AppColors.surface : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          boxShadow: isEnabled ? AppShadows.card : null,
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isEnabled ? color.withOpacity(0.1) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              ),
              child: Icon(
                icon,
                size: 32,
                color: isEnabled ? color : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: AppDimens.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.subhead1.copyWith(
                      color: isEnabled ? AppColors.textPrimary : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacing4),
                  Text(
                    isEnabled ? description : '여행을 먼저 선택해주세요',
                    style: AppTypography.body2.copyWith(
                      color: isEnabled ? AppColors.textSecondary : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isEnabled ? AppColors.textSecondary : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _showTripRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('추억을 만들 여행을 먼저 선택해주세요'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  Widget _buildPreviousMemories() {
    // TODO: 실제 저장된 추억 데이터 연동
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이전에 만든 추억', style: AppTypography.subhead1),
        const SizedBox(height: AppDimens.spacing12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimens.spacing32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: AppDimens.spacing12),
              Text(
                '아직 만든 추억이 없어요',
                style: AppTypography.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
