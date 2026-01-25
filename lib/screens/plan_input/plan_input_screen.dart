import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';
import '../../services/api_service.dart';

/// 새 여행 계획 입력 화면
/// - 단계별 입력 방식 (5단계)
/// - Travel Planner Agent 호출
class PlanInputScreen extends StatefulWidget {
  const PlanInputScreen({super.key});

  @override
  State<PlanInputScreen> createState() => _PlanInputScreenState();
}

class _PlanInputScreenState extends State<PlanInputScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: 목적지 (오사카 또는 제주도만)
  String? _selectedDestination;

  // Step 2: 여행 기간
  DateTimeRange? _dateRange;

  // Step 3: 여행 인원
  int _travelers = 2;

  // Step 4: 숙소 위치
  final TextEditingController _accommodationController = TextEditingController();

  // Step 5: 여행 스타일
  final Set<TravelStyle> _selectedStyles = {};
  final TextEditingController _customPreferenceController = TextEditingController();

  final List<String> _stepTitles = [
    '어디로 떠나시나요?',
    '언제 여행하시나요?',
    '몇 명이 함께하나요?',
    '숙소 위치는 어디인가요?',
    '어떤 여행을 원하시나요?',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _accommodationController.dispose();
    _customPreferenceController.dispose();
    super.dispose();
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _selectedDestination != null;
      case 1:
        return _dateRange != null;
      case 2:
        return _travelers > 0;
      case 3:
        return true; // 숙소 위치는 건너뛰기 가능
      case 4:
        return _selectedStyles.isNotEmpty || _customPreferenceController.text.isNotEmpty;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: AppTheme.animationDuration,
        curve: AppTheme.animationCurve,
      );
    } else {
      _generatePlan();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: AppTheme.animationDuration,
        curve: AppTheme.animationCurve,
      );
    } else {
      context.pop();
    }
  }

  Future<void> _generatePlan() async {
    setState(() => _isLoading = true);

    try {
      // 실제 API 호출
      final apiService = ApiService();
      final trip = await apiService.generateTravelPlan(
        destination: _selectedDestination!,
        startDate: _dateRange!.start,
        endDate: _dateRange!.end,
        travelers: _travelers,
        budget: 500000, // 기본 예산 (추후 입력 받을 수 있음)
        styles: _selectedStyles.map((s) => s.name).toList(),
        accommodationLocation: _accommodationController.text.isNotEmpty
            ? _accommodationController.text
            : null,
        customPreference: _customPreferenceController.text.isNotEmpty
            ? _customPreferenceController.text
            : null,
      );

      // Provider에 저장
      await context.read<TripProvider>().addTrip(trip);

      if (mounted) {
        context.go(AppRoutes.planResult, extra: trip.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정 생성에 실패했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Trip _createDummyTrip() {
    final uuid = const Uuid();
    return Trip(
      id: uuid.v4(),
      destination: _selectedDestination!,
      period: TripPeriod(
        start: _dateRange!.start,
        end: _dateRange!.end,
      ),
      travelers: _travelers,
      budget: const Budget(estimated: 0), // 예산 입력 제거됨
      styles: _selectedStyles.toList(),
      customPreference: _customPreferenceController.text.isNotEmpty
          ? _customPreferenceController.text
          : null,
      accommodationLocation: _accommodationController.text.isNotEmpty
          ? _accommodationController.text
          : null,
      dailyPlans: [], // AI가 채울 예정
      status: TripStatus.upcoming,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _previousStep,
        ),
        title: Text(
          '새 여행 계획',
          style: AppTypography.subhead1,
        ),
      ),
      body: Column(
        children: [
          // 프로그레스 바
          _buildProgressBar(),

          // 단계별 컨텐츠
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildDestinationStep(),
                _buildDateStep(),
                _buildTravelersStep(),
                _buildAccommodationStep(),
                _buildStyleStep(),
              ],
            ),
          ),

          // 하단 버튼
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacing20,
        vertical: AppDimens.spacing12,
      ),
      child: Row(
        children: List.generate(5, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isCompleted || isCurrent
                    ? AppColors.accent
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepTitle() {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spacing20),
      child: Text(
        _stepTitles[_currentStep],
        style: AppTypography.headline3,
      ),
    );
  }

  // Step 1: 목적지 선택 (오사카 또는 제주도)
  Widget _buildDestinationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_stepTitles[0], style: AppTypography.headline3),
          const SizedBox(height: AppDimens.spacing8),
          Text(
            '특별한 여행지를 선택하세요',
            style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spacing32),
          // 오사카 카드
          _buildDestinationCard(
            destination: '오사카',
            description: '맛집과 쇼핑의 천국, 활기찬 일본 여행',
            icon: Icons.ramen_dining,
            isSelected: _selectedDestination == '오사카',
          ),
          const SizedBox(height: AppDimens.spacing16),
          // 제주도 카드
          _buildDestinationCard(
            destination: '제주도',
            description: '자연과 힐링의 섬, 아름다운 국내 여행',
            icon: Icons.terrain,
            isSelected: _selectedDestination == '제주도',
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard({
    required String destination,
    required String description,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedDestination = destination),
      child: AnimatedContainer(
        duration: AppTheme.animationDuration,
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimens.spacing20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppShadows.card : null,
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent.withOpacity(0.2)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              ),
              child: Icon(
                icon,
                size: 32,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppDimens.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination,
                    style: AppTypography.subhead1.copyWith(
                      color: isSelected ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacing4),
                  Text(
                    description,
                    style: AppTypography.body2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.accent),
          ],
        ),
      ),
    );
  }

  // Step 2: 여행 기간
  Widget _buildDateStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_stepTitles[1], style: AppTypography.headline3),
          const SizedBox(height: AppDimens.spacing24),
          GestureDetector(
            onTap: _selectDateRange,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimens.spacing16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.primary),
                  const SizedBox(width: AppDimens.spacing12),
                  Expanded(
                    child: Text(
                      _dateRange != null
                          ? '${_formatDate(_dateRange!.start)} ~ ${_formatDate(_dateRange!.end)}'
                          : '날짜를 선택하세요',
                      style: AppTypography.body1.copyWith(
                        color: _dateRange != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (_dateRange != null)
                    Text(
                      '${_dateRange!.duration.inDays + 1}일',
                      style: AppTypography.body2.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (result != null) {
      setState(() => _dateRange = result);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}월 ${date.day}일';
  }

  // Step 3: 여행 인원
  Widget _buildTravelersStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_stepTitles[2], style: AppTypography.headline3),
          const SizedBox(height: AppDimens.spacing48),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCounterButton(
                  icon: Icons.remove,
                  onPressed:
                      _travelers > 1 ? () => setState(() => _travelers--) : null,
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppDimens.spacing32),
                  child: Text(
                    '$_travelers명',
                    style: AppTypography.headline1,
                  ),
                ),
                _buildCounterButton(
                  icon: Icons.add,
                  onPressed:
                      _travelers < 20 ? () => setState(() => _travelers++) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: onPressed != null ? AppColors.primary : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  // Step 4: 숙소 위치
  Widget _buildAccommodationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_stepTitles[3], style: AppTypography.headline3),
          const SizedBox(height: AppDimens.spacing8),
          Text(
            '숙소 근처로 일정을 최적화해드려요',
            style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spacing24),
          TextField(
            controller: _accommodationController,
            decoration: InputDecoration(
              hintText: '예: 난바역, 제주시청 근처',
              prefixIcon: const Icon(Icons.hotel_outlined),
              suffixIcon: _accommodationController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _accommodationController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            style: AppTypography.body1,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppDimens.spacing16),
          // 추천 숙소 위치
          if (_selectedDestination == '오사카')
            _buildAccommodationSuggestions(['난바역', '우메다역', '신사이바시', '도톤보리'])
          else if (_selectedDestination == '제주도')
            _buildAccommodationSuggestions(['제주시청', '서귀포시', '애월읍', '중문관광단지']),
        ],
      ),
    );
  }

  Widget _buildAccommodationSuggestions(List<String> suggestions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '추천 위치',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppDimens.spacing8),
        Wrap(
          spacing: AppDimens.spacing8,
          runSpacing: AppDimens.spacing8,
          children: suggestions
              .map((location) => ActionChip(
                    label: Text(location),
                    onPressed: () {
                      _accommodationController.text = location;
                      setState(() {});
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  // Step 5: 여행 스타일
  Widget _buildStyleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_stepTitles[4], style: AppTypography.headline3),
          const SizedBox(height: AppDimens.spacing8),
          Text(
            '키워드 선택 또는 직접 입력하세요',
            style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spacing24),
          // 키워드 선택
          Text(
            '키워드 선택',
            style: AppTypography.subhead2,
          ),
          const SizedBox(height: AppDimens.spacing12),
          Wrap(
            spacing: AppDimens.spacing12,
            runSpacing: AppDimens.spacing12,
            children: TravelStyle.values.map((style) {
              final isSelected = _selectedStyles.contains(style);
              return FilterChip(
                label: Text(style.label),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedStyles.add(style);
                    } else {
                      _selectedStyles.remove(style);
                    }
                  });
                },
                selectedColor: AppColors.accent.withOpacity(0.15),
                checkmarkColor: AppColors.accent,
                labelStyle: AppTypography.body2.copyWith(
                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacing12,
                  vertical: AppDimens.spacing8,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppDimens.spacing24),
          // 직접 입력
          Text(
            '또는 직접 입력',
            style: AppTypography.subhead2,
          ),
          const SizedBox(height: AppDimens.spacing12),
          TextField(
            controller: _customPreferenceController,
            decoration: const InputDecoration(
              hintText: '원하는 여행 스타일을 자유롭게 입력하세요',
              prefixIcon: Icon(Icons.edit_note),
            ),
            style: AppTypography.body1,
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppDimens.spacing8),
          Text(
            '예: 현지인 맛집 위주, 사진 찍기 좋은 카페, 야경 명소 등',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    // 숙소 위치 단계(3)에서 건너뛰기 버튼 표시
    final showSkipButton = _currentStep == 3;

    return Container(
      padding: const EdgeInsets.all(AppDimens.spacing20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSkipButton) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: !_isLoading ? _skipStep : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('건너뛰기'),
                ),
              ),
              const SizedBox(height: AppDimens.spacing8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canProceed() && !_isLoading ? _nextStep : null,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(_currentStep == 4 ? 'AI 일정 생성하기' : '다음'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _skipStep() {
    // 숙소 위치 건너뛰기 - 컨트롤러 비우고 다음 단계로
    _accommodationController.clear();
    _nextStep();
  }
}
