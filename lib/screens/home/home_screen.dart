import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../providers/app_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/trip.dart';
import '../../widgets/common/trip_card.dart';

/// 홈 화면 - 메인 대시보드
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final tripProvider = context.watch<TripProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.spacing20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 인사말
              _buildGreeting(appProvider.displayName),
              const SizedBox(height: AppDimens.spacing24),

              // 빠른 액션 카드 그리드
              _buildQuickActions(context),
              const SizedBox(height: AppDimens.spacing32),

              // 최근 여행 섹션
              _buildRecentTrips(context, tripProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(String name) {
    final now = DateTime.now();
    final dateString = '${now.year}년 ${now.month}월 ${now.day}일';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '안녕하세요, $name님',
          style: AppTypography.headline3,
        ),
        const SizedBox(height: AppDimens.spacing4),
        Text(
          dateString,
          style: AppTypography.caption,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      QuickAction(
        icon: Icons.add_location_alt_outlined,
        label: '새 여행 계획',
        color: AppColors.accent,
        onTap: () => context.push(AppRoutes.planInput),
      ),
      QuickAction(
        icon: Icons.chat_bubble_outline,
        label: 'AI 컨설턴트',
        color: AppColors.info,
        onTap: () => context.push(AppRoutes.aiConsultant),
      ),
      QuickAction(
        icon: Icons.luggage_outlined,
        label: '내 여행',
        color: AppColors.success,
        onTap: () => context.push(AppRoutes.myTrips),
      ),
      QuickAction(
        icon: Icons.photo_library_outlined,
        label: '추억 남기기',
        color: AppColors.day4Plus,
        onTap: () => context.push(AppRoutes.memories),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppDimens.spacing16,
        crossAxisSpacing: AppDimens.spacing16,
        childAspectRatio: 1.3,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        return _buildActionCard(actions[index]);
      },
    );
  }

  Widget _buildActionCard(QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spacing16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                action.icon,
                color: action.color,
                size: 24,
              ),
            ),
            Text(
              action.label,
              style: AppTypography.subhead2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTrips(BuildContext context, TripProvider tripProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '최근 여행',
              style: AppTypography.subhead1,
            ),
            if (tripProvider.trips.isNotEmpty)
              TextButton(
                onPressed: () => context.push(AppRoutes.myTrips),
                child: const Text('전체보기'),
              ),
          ],
        ),
        const SizedBox(height: AppDimens.spacing12),

        if (tripProvider.trips.isEmpty)
          _buildEmptyState(context)
        else
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tripProvider.trips.take(5).length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppDimens.spacing12),
              itemBuilder: (context, index) {
                final trip = tripProvider.trips[index];
                return TripCard(
                  trip: trip,
                  onTap: () => context.push(
                    AppRoutes.tripDetail.replaceFirst(':tripId', trip.id),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.spacing32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(
          color: Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.flight_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: AppDimens.spacing16),
          Text(
            '아직 여행 계획이 없어요',
            style: AppTypography.body1.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spacing16),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.planInput),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('새 여행 계획하기'),
          ),
        ],
      ),
    );
  }
}

class QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
