import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';

/// 나만의 영상 화면
/// - AI로 시네마틱 영상 생성
/// - Google Gemini Veo 3.1 사용
/// - 선택한 여행의 갤러리 미디어만 업로드 가능
class VideoCreatorScreen extends StatefulWidget {
  final String? tripId;

  const VideoCreatorScreen({super.key, this.tripId});

  @override
  State<VideoCreatorScreen> createState() => _VideoCreatorScreenState();
}

class _VideoCreatorScreenState extends State<VideoCreatorScreen> {
  final List<String> _selectedMedia = [];
  String? _selectedStyle;
  String? _selectedMusic;
  int _duration = 30;
  bool _isProcessing = false;
  Trip? _trip;

  final List<VideoStyle> _styles = [
    VideoStyle('cinematic', '시네마틱 여행', Icons.movie_creation),
    VideoStyle('vlog', '감성 브이로그', Icons.videocam),
    VideoStyle('highlight', '다이나믹 하이라이트', Icons.flash_on),
    VideoStyle('album', '추억 앨범', Icons.photo_album),
  ];

  final List<MusicOption> _musicOptions = [
    MusicOption('calm', '잔잔한', Icons.waves),
    MusicOption('upbeat', '신나는', Icons.music_note),
    MusicOption('emotional', '감성적인', Icons.favorite),
    MusicOption('none', '없음', Icons.volume_off),
  ];

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  void _loadTrip() {
    if (widget.tripId != null) {
      final tripProvider = context.read<TripProvider>();
      _trip = tripProvider.getTripById(widget.tripId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 여행이 선택되지 않은 경우
    if (widget.tripId == null || _trip == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text('나만의 영상', style: AppTypography.subhead1),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: AppDimens.spacing16),
              Text(
                '여행을 먼저 선택해주세요',
                style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('나만의 영상', style: AppTypography.subhead1),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.spacing20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 미디어 선택
                  _buildMediaSelector(),
                  const SizedBox(height: AppDimens.spacing24),

                  // 영상 스타일
                  _buildStyleSelector(),
                  const SizedBox(height: AppDimens.spacing24),

                  // 배경음악
                  _buildMusicSelector(),
                  const SizedBox(height: AppDimens.spacing24),

                  // 영상 길이
                  _buildDurationSelector(),
                ],
              ),
            ),
          ),

          // 하단 버튼
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildMediaSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 선택된 여행 정보 표시
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimens.spacing12),
          margin: const EdgeInsets.only(bottom: AppDimens.spacing16),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          ),
          child: Row(
            children: [
              const Icon(Icons.flight, size: 20, color: AppColors.info),
              const SizedBox(width: AppDimens.spacing8),
              Expanded(
                child: Text(
                  '${_trip!.destination} (${_trip!.period.displayString})',
                  style: AppTypography.body2.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('미디어 선택', style: AppTypography.subhead2),
            Text(
              '${_selectedMedia.length}/20',
              style: AppTypography.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spacing8),
        Text(
          '${_trip!.destination} 여행 기간(${_trip!.period.displayString})에 촬영된 갤러리 미디어만 선택할 수 있습니다',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppDimens.spacing12),

        // 미디어 타입 탭
        DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                ),
                child: TabBar(
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicator: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  ),
                  tabs: const [
                    Tab(text: '전체'),
                    Tab(text: '사진'),
                    Tab(text: '영상'),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.spacing12),
            ],
          ),
        ),

        // 미디어 그리드
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _selectedMedia.isEmpty
              ? _buildEmptyMediaState()
              : _buildMediaGrid(),
        ),
      ],
    );
  }

  Widget _buildEmptyMediaState() {
    return InkWell(
      onTap: _selectMedia,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo_outlined,
                size: 28,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: AppDimens.spacing8),
            Text(
              '미디어를 선택하세요',
              style: AppTypography.body1.copyWith(color: AppColors.info),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid() {
    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(AppDimens.spacing8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: _selectedMedia.length,
          itemBuilder: (context, index) {
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Icon(Icons.photo, color: Colors.grey, size: 20),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMedia.removeAt(index);
                      });
                    },
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        Positioned(
          right: AppDimens.spacing8,
          bottom: AppDimens.spacing8,
          child: FloatingActionButton.small(
            onPressed: _selectMedia,
            backgroundColor: AppColors.info,
            child: const Icon(Icons.add, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildStyleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('영상 스타일', style: AppTypography.subhead2),
        const SizedBox(height: AppDimens.spacing12),
        Wrap(
          spacing: AppDimens.spacing8,
          runSpacing: AppDimens.spacing8,
          children: _styles.map((style) {
            final isSelected = _selectedStyle == style.id;
            return GestureDetector(
              onTap: () => setState(() => _selectedStyle = style.id),
              child: AnimatedContainer(
                duration: AppTheme.animationDuration,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacing16,
                  vertical: AppDimens.spacing12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.info.withOpacity(0.1)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  border: Border.all(
                    color: isSelected ? AppColors.info : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      style.icon,
                      size: 20,
                      color: isSelected ? AppColors.info : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppDimens.spacing8),
                    Text(
                      style.label,
                      style: AppTypography.body2.copyWith(
                        color: isSelected ? AppColors.info : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMusicSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('배경음악', style: AppTypography.subhead2),
        const SizedBox(height: AppDimens.spacing12),
        Row(
          children: _musicOptions.map((option) {
            final isSelected = _selectedMusic == option.id;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedMusic = option.id),
                child: AnimatedContainer(
                  duration: AppTheme.animationDuration,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withOpacity(0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        option.icon,
                        size: 24,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppDimens.spacing4),
                      Text(
                        option.label,
                        style: AppTypography.caption.copyWith(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('영상 길이', style: AppTypography.subhead2),
        const SizedBox(height: AppDimens.spacing12),
        Row(
          children: [15, 30, 60].map((seconds) {
            final isSelected = _duration == seconds;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _duration = seconds),
                child: AnimatedContainer(
                  duration: AppTheme.animationDuration,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${seconds}초',
                      style: AppTypography.subhead2.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    final canProcess = _selectedMedia.isNotEmpty &&
        _selectedStyle != null &&
        _selectedMusic != null &&
        !_isProcessing;

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
            if (_isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spacing12),
                child: Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: AppDimens.spacing8),
                    Text(
                      '특별한 영상을 만들고 있어요...',
                      style: AppTypography.body2.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canProcess ? _createVideo : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.videocam),
                label: Text(_isProcessing ? '생성 중...' : 'AI 영상 만들기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectMedia() {
    // TODO: 실제 갤러리 연동
    setState(() {
      if (_selectedMedia.length < 20) {
        _selectedMedia.add('media_${_selectedMedia.length + 1}');
      }
    });
  }

  Future<void> _createVideo() async {
    setState(() => _isProcessing = true);

    try {
      // TODO: 실제 API 연동
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('영상이 생성되었습니다!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('생성 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}

class VideoStyle {
  final String id;
  final String label;
  final IconData icon;

  VideoStyle(this.id, this.label, this.icon);
}

class MusicOption {
  final String id;
  final String label;
  final IconData icon;

  MusicOption(this.id, this.label, this.icon);
}
