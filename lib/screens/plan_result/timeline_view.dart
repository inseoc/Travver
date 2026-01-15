import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/models.dart';

/// 타임라인 뷰 컴포넌트
/// - 일정을 시간순으로 표시
class TimelineView extends StatelessWidget {
  final List<DailyPlan> dailyPlans;
  final int? selectedScheduleIndex;
  final Function(int dayIndex, int scheduleIndex)? onScheduleTap;

  const TimelineView({
    super.key,
    required this.dailyPlans,
    this.selectedScheduleIndex,
    this.onScheduleTap,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyPlans.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimens.spacing16),
      itemCount: dailyPlans.length,
      itemBuilder: (context, dayIndex) {
        final plan = dailyPlans[dayIndex];
        return _buildDaySection(plan, dayIndex);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: AppDimens.spacing16),
          Text(
            '일정이 없습니다',
            style: AppTypography.body1.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(DailyPlan plan, int dayIndex) {
    final dayColor = AppColors.getDayColor(plan.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day 헤더
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacing12,
                  vertical: AppDimens.spacing4,
                ),
                decoration: BoxDecoration(
                  color: dayColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                ),
                child: Text(
                  'Day ${plan.day}',
                  style: AppTypography.body2.copyWith(
                    color: dayColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spacing8),
              Text(
                plan.dateString,
                style: AppTypography.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // 테마
        if (plan.theme.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spacing12),
            child: Text(
              plan.theme,
              style: AppTypography.subhead2,
            ),
          ),

        // 일정 목록
        ...plan.schedules.asMap().entries.map((entry) {
          final scheduleIndex = entry.key;
          final schedule = entry.value;
          final isLast = scheduleIndex == plan.schedules.length - 1;

          return _buildScheduleItem(
            schedule,
            dayColor,
            dayIndex,
            scheduleIndex,
            isLast,
          );
        }),

        const SizedBox(height: AppDimens.spacing16),
      ],
    );
  }

  Widget _buildScheduleItem(
    Schedule schedule,
    Color dayColor,
    int dayIndex,
    int scheduleIndex,
    bool isLast,
  ) {
    return GestureDetector(
      onTap: () => onScheduleTap?.call(dayIndex, scheduleIndex),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 타임라인 라인
            SizedBox(
              width: 60,
              child: Column(
                children: [
                  // 시간 표시
                  Text(
                    schedule.time,
                    style: AppTypography.body2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 점
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: dayColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // 연결선
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: dayColor.withOpacity(0.3),
                      ),
                    ),
                ],
              ),
            ),

            // 일정 카드
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(
                  left: AppDimens.spacing8,
                  bottom: AppDimens.spacing12,
                ),
                padding: const EdgeInsets.all(AppDimens.spacing12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 장소명 + 카테고리
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            schedule.place,
                            style: AppTypography.subhead2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spacing8,
                            vertical: AppDimens.spacing4,
                          ),
                          decoration: BoxDecoration(
                            color: dayColor.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusSmall),
                          ),
                          child: Text(
                            schedule.category.label,
                            style: AppTypography.caption.copyWith(
                              color: dayColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 설명
                    if (schedule.description.isNotEmpty) ...[
                      const SizedBox(height: AppDimens.spacing8),
                      Text(
                        schedule.description,
                        style: AppTypography.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // 소요 시간 + 예상 비용
                    const SizedBox(height: AppDimens.spacing8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          schedule.durationString,
                          style: AppTypography.caption,
                        ),
                        const SizedBox(width: AppDimens.spacing16),
                        Icon(
                          Icons.payments_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          schedule.costString,
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
