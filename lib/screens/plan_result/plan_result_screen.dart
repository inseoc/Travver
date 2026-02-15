import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../models/models.dart';
import '../../providers/trip_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/map/trip_map_widget.dart';
import 'timeline_view.dart';

/// 여행 계획 결과 화면
/// - 상하 분할 (지도 뷰 + 타임라인 뷰)
/// - Travel Planner Agent 결과 표시
class PlanResultScreen extends StatefulWidget {
  final String? tripId;

  const PlanResultScreen({super.key, this.tripId});

  @override
  State<PlanResultScreen> createState() => _PlanResultScreenState();
}

class _PlanResultScreenState extends State<PlanResultScreen> {
  int _selectedDay = 0; // 0 = 전체보기
  int? _selectedScheduleIndex;
  double _mapHeightRatio = 0.4;
  bool _isModifying = false;

  Trip? _trip;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  void _loadTrip() {
    final tripProvider = context.read<TripProvider>();
    if (widget.tripId != null) {
      _trip = tripProvider.getTripById(widget.tripId!);
    }
    _trip ??= tripProvider.currentTrip;
  }

  List<DailyPlan> get _filteredPlans {
    if (_trip == null) return [];
    if (_selectedDay == 0) return _trip!.dailyPlans;
    return _trip!.dailyPlans
        .where((plan) => plan.day == _selectedDay)
        .toList();
  }

  void _onScheduleTap(int dayIndex, int scheduleIndex) {
    setState(() {
      _selectedScheduleIndex = scheduleIndex;
    });
  }

  void _onMarkerTap(int scheduleIndex) {
    setState(() {
      _selectedScheduleIndex = scheduleIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('여행 일정')),
        body: const Center(child: Text('여행 정보를 찾을 수 없습니다')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Text(_trip!.destination, style: AppTypography.subhead1),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단: 지도 뷰
          _buildMapSection(),

          // 드래그 핸들
          _buildDragHandle(),

          // 하단: Day 탭 + 타임라인
          Expanded(
            child: Column(
              children: [
                _buildDayTabs(),
                Expanded(
                  child: TimelineView(
                    dailyPlans: _filteredPlans,
                    selectedScheduleIndex: _selectedScheduleIndex,
                    onScheduleTap: _onScheduleTap,
                    onDayEdit: _showDayEditDialog,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingButtons(),
    );
  }

  Widget _buildMapSection() {
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight * _mapHeightRatio;

    return SizedBox(
      height: mapHeight.clamp(150.0, screenHeight * 0.6),
      child: TripMapWidget(
        dailyPlans: _filteredPlans,
        selectedDay: _selectedDay,
        selectedScheduleIndex: _selectedScheduleIndex,
        onMarkerTap: _onMarkerTap,
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _mapHeightRatio += details.delta.dy / MediaQuery.of(context).size.height;
          _mapHeightRatio = _mapHeightRatio.clamp(0.2, 0.6);
        });
      },
      child: Container(
        height: 24,
        color: AppColors.surface,
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayTabs() {
    if (_trip == null || _trip!.dailyPlans.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 48,
      color: AppColors.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacing12),
        children: [
          // 전체보기 탭
          _buildDayTab(0, '전체'),
          // Day별 탭
          ...List.generate(_trip!.dailyPlans.length, (index) {
            final day = index + 1;
            return _buildDayTab(day, 'Day $day');
          }),
        ],
      ),
    );
  }

  Widget _buildDayTab(int day, String label) {
    final isSelected = _selectedDay == day;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacing4,
        vertical: AppDimens.spacing8,
      ),
      child: Material(
        color: isSelected ? AppColors.accent : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: InkWell(
          onTap: () => setState(() => _selectedDay = day),
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacing16,
              vertical: AppDimens.spacing8,
            ),
            child: Text(
              label,
              style: AppTypography.body2.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return FloatingActionButton.extended(
      heroTag: 'save',
      onPressed: _saveTrip,
      icon: const Icon(Icons.check),
      label: const Text('저장'),
    );
  }

  void _showOptionsMenu() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripStart = _trip != null
        ? DateTime(
            _trip!.period.start.year,
            _trip!.period.start.month,
            _trip!.period.start.day,
          )
        : null;
    final isMemoryEligible =
        tripStart != null && !tripStart.isAfter(today);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMemoryEligible) ...[
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined,
                      color: AppColors.accent),
                  title: const Text('추억 갤러리'),
                  subtitle: const Text('저장된 꾸며진 사진 보기'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(
                        AppRoutes.tripMemories, extra: _trip!.id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome,
                      color: AppColors.accent),
                  title: const Text('사진 꾸미기'),
                  subtitle: const Text('AI로 여행 사진을 꾸며보세요'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(
                        AppRoutes.photoDecorator, extra: _trip!.id);
                  },
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('공유하기'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 공유 기능 구현
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('삭제하기', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteTrip();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDayEditDialog(int dayNumber) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Day $dayNumber 일정 수정'),
          content: TextField(
            controller: controller,
            maxLength: 50,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '수정 요청을 입력하세요',
              hintStyle: TextStyle(fontSize: 14),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              counterText: '',
            ),
            style: const TextStyle(fontSize: 14),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.pop(dialogContext);
                _modifyDaySchedule(dayNumber, value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  _modifyDaySchedule(dayNumber, text);
                }
              },
              child: const Text('수정'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _modifyDaySchedule(int dayNumber, String prompt) async {
    if (_trip == null || _isModifying) return;

    setState(() => _isModifying = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI가 일정을 수정하고 있습니다...')),
    );

    try {
      final modifiedPlan = await _apiService.modifyDayPlan(
        tripId: _trip!.id,
        day: dayNumber,
        prompt: prompt,
      );

      if (mounted) {
        setState(() {
          final updatedPlans = _trip!.dailyPlans.map((plan) {
            if (plan.day == dayNumber) {
              return modifiedPlan;
            }
            return plan;
          }).toList();

          _trip = _trip!.copyWith(dailyPlans: updatedPlans);
        });

        // Provider에도 반영
        context.read<TripProvider>().updateTrip(_trip!);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Day $dayNumber 일정이 수정되었습니다'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정 수정 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isModifying = false);
    }
  }

  Future<void> _saveTrip() async {
    if (_trip == null) return;

    try {
      await context.read<TripProvider>().updateTrip(_trip!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('여행이 저장되었습니다'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('여행 삭제'),
        content: const Text('이 여행을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true && _trip != null) {
      await context.read<TripProvider>().deleteTrip(_trip!.id);
      if (mounted) {
        context.go(AppRoutes.home);
      }
    }
  }
}
