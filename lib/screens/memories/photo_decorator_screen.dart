import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// 사진 꾸미기 화면
/// - AI로 여행 사진을 예술적으로 꾸미기
/// - Google Gemini Nano Banana Pro 사용
class PhotoDecoratorScreen extends StatefulWidget {
  final String? tripId;

  const PhotoDecoratorScreen({super.key, this.tripId});

  @override
  State<PhotoDecoratorScreen> createState() => _PhotoDecoratorScreenState();
}

class _PhotoDecoratorScreenState extends State<PhotoDecoratorScreen> {
  final List<String> _selectedPhotos = [];
  String? _selectedStyle;
  bool _isProcessing = false;

  final List<PhotoStyle> _styles = [
    PhotoStyle('watercolor', '수채화', Icons.water_drop),
    PhotoStyle('oil_painting', '유화', Icons.brush),
    PhotoStyle('sketch', '스케치', Icons.edit),
    PhotoStyle('vintage', '빈티지', Icons.photo_camera_back),
    PhotoStyle('movie_poster', '영화 포스터', Icons.movie),
    PhotoStyle('pop_art', '팝아트', Icons.palette),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('사진 꾸미기', style: AppTypography.subhead1),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.spacing20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 사진 선택 영역
                  _buildPhotoSelector(),
                  const SizedBox(height: AppDimens.spacing24),

                  // 스타일 선택
                  _buildStyleSelector(),
                  const SizedBox(height: AppDimens.spacing24),

                  // 미리보기
                  if (_selectedPhotos.isNotEmpty) _buildPreview(),
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

  Widget _buildPhotoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('사진 선택', style: AppTypography.subhead2),
            Text(
              '${_selectedPhotos.length}/10',
              style: AppTypography.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spacing8),
        Text(
          '여행 기간에 촬영된 사진만 표시됩니다',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppDimens.spacing12),

        // 갤러리 그리드
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _selectedPhotos.isEmpty
              ? _buildEmptyPhotoState()
              : _buildPhotoGrid(),
        ),
      ],
    );
  }

  Widget _buildEmptyPhotoState() {
    return InkWell(
      onTap: _selectPhotos,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 32,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppDimens.spacing12),
            Text(
              '사진을 선택하세요',
              style: AppTypography.body1.copyWith(color: AppColors.accent),
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              '최대 10장까지 선택 가능',
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(AppDimens.spacing8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: _selectedPhotos.length,
          itemBuilder: (context, index) {
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Icon(Icons.photo, color: Colors.grey),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPhotos.removeAt(index);
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
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
            onPressed: _selectPhotos,
            backgroundColor: AppColors.accent,
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
        Text('스타일 선택', style: AppTypography.subhead2),
        const SizedBox(height: AppDimens.spacing12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _styles.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppDimens.spacing12),
            itemBuilder: (context, index) {
              final style = _styles[index];
              final isSelected = _selectedStyle == style.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedStyle = style.id),
                child: AnimatedContainer(
                  duration: AppTheme.animationDuration,
                  width: 80,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withOpacity(0.1)
                        : AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusMedium),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        style.icon,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppDimens.spacing8),
                      Text(
                        style.label,
                        style: AppTypography.caption.copyWith(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('미리보기', style: AppTypography.subhead2),
        const SizedBox(height: AppDimens.spacing12),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: AppDimens.spacing8),
                Text(
                  '스타일 적용 후 미리보기가 표시됩니다',
                  style: AppTypography.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    final canProcess =
        _selectedPhotos.isNotEmpty && _selectedStyle != null && !_isProcessing;

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
          child: ElevatedButton.icon(
            onPressed: canProcess ? _processPhotos : null,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_isProcessing ? '처리 중...' : 'AI로 꾸미기 시작'),
          ),
        ),
      ),
    );
  }

  void _selectPhotos() {
    // TODO: 실제 갤러리 연동
    // 임시로 더미 데이터 추가
    setState(() {
      if (_selectedPhotos.length < 10) {
        _selectedPhotos.add('photo_${_selectedPhotos.length + 1}');
      }
    });
  }

  Future<void> _processPhotos() async {
    setState(() => _isProcessing = true);

    try {
      // TODO: 실제 API 연동
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진 꾸미기가 완료되었습니다!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('처리 실패: $e'),
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

class PhotoStyle {
  final String id;
  final String label;
  final IconData icon;

  PhotoStyle(this.id, this.label, this.icon);
}
