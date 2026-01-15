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

  // Step 1: 목적지
  final TextEditingController _destinationController = TextEditingController();

  // Step 2: 여행 기간
  DateTimeRange? _dateRange;

  // Step 3: 여행 인원
  int _travelers = 2;

  // Step 4: 예산 범위
  double _budget = 500000;

  // Step 5: 여행 스타일
  final Set<TravelStyle> _selectedStyles = {};

  final List<String> _stepTitles = [
    '어디로 떠나시나요?',
    '언제 여행하시나요?',
    '몇 명이 함께하나요?',
    '예산은 어느 정도인가요?',
    '어떤 여행을 원하시나요?',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _destinationController.text.isNotEmpty;
      case 1:
        return _dateRange != null;
      case 2:
        return _travelers > 0;
      case 3:
        return _budget > 0;
      case 4:
        return _selectedStyles.isNotEmpty;
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
      // TODO: 실제 API 연동 시 아래 코드 활성화
      // final apiService = ApiService();
      // final trip = await apiService.generateTravelPlan(
      //   destination: _destinationController.text,
      //   startDate: _dateRange!.start,
      //   endDate: _dateRange!.end,
      //   travelers: _travelers,
      //   budget: _budget.toInt(),
      //   styles: _selectedStyles.map((s) => s.name).toList(),
      // );

      // 임시 더미 데이터 생성
      final trip = _createDummyTrip();

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
      destination: _destinationController.text,
      period: TripPeriod(
        start: _dateRange!.start,
        end: _dateRange!.end,
      ),
      travelers: _travelers,
      budget: Budget(estimated: _budget.toInt()),
      styles: _selectedStyles.toList(),
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
                _buildBudgetStep(),
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

  // Step 1: 목적지 입력
  Widget _buildDestinationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_stepTitles[0], style: AppTypography.headline3),
          const SizedBox(height: AppDimens.spacing24),
          TextField(
            controller: _destinationController,
            decoration: const InputDecoration(
              hintText: '도시 또는 국가 입력',
              prefixIcon: Icon(Icons.search),
            ),
            style: AppTypography.body1,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppDimens.spacing16),
          // 인기 여행지 추천
          Wrap(
            spacing: AppDimens.spacing8,
            runSpacing: AppDimens.spacing8,
            children: ['도쿄', '오사카', '방콕', '파리', '제주도', '부산']
                .map((city) => ActionChip(
                      label: Text(city),
                      onPressed: () {
                        _destinationController.text = city;
                        setState(() {});
                      },
                    ))
                .toList(),
          ),
        ],
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

  // Step 4: 예산 범위
  Widget _buildBudgetStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_stepTitles[3], style: AppTypography.headline3),
          const SizedBox(height: AppDimens.spacing48),
          Center(
            child: Text(
              '${_formatBudget(_budget.toInt())}원',
              style: AppTypography.headline1.copyWith(
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spacing8),
          Center(
            child: Text(
              '1인당 예상 비용',
              style: AppTypography.caption,
            ),
          ),
          const SizedBox(height: AppDimens.spacing32),
          Slider(
            value: _budget,
            min: 100000,
            max: 5000000,
            divisions: 49,
            activeColor: AppColors.accent,
            inactiveColor: Colors.grey.shade300,
            onChanged: (value) => setState(() => _budget = value),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacing8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('10만원', style: AppTypography.caption),
                Text('500만원', style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBudget(int budget) {
    return budget.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
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
            '여러 개 선택 가능해요',
            style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spacing24),
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
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
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
        child: SizedBox(
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
      ),
    );
  }
}
