import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';
import '../../services/api_service.dart';

/// 사진 꾸미기 화면
class PhotoDecoratorScreen extends StatefulWidget {
  final String? tripId;

  const PhotoDecoratorScreen({super.key, this.tripId});

  @override
  State<PhotoDecoratorScreen> createState() => _PhotoDecoratorScreenState();
}

class _SelectedPhoto {
  final String name;
  final Uint8List? bytes;
  final String? path;

  _SelectedPhoto({required this.name, this.bytes, this.path});
}

/// 개별 사진의 꾸미기 상태
class _PhotoItem {
  final _SelectedPhoto original;
  String? selectedStyle;
  Uint8List? decoratedBytes;
  String? decoratedBase64;
  String? decoratedMimeType;
  bool isProcessing;
  String? savedPhotoId;

  _PhotoItem({required this.original})
      : isProcessing = false;

  bool get isDecorated => decoratedBytes != null;
  bool get isSaved => savedPhotoId != null;
}

class _PhotoDecoratorScreenState extends State<PhotoDecoratorScreen> {
  final List<_PhotoItem> _photoItems = [];
  Trip? _trip;
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();

  final List<PhotoStyle> _styles = [
    PhotoStyle('watercolor', '수채화', Icons.water_drop),
    PhotoStyle('oil_painting', '유화', Icons.brush),
    PhotoStyle('sketch', '스케치', Icons.edit),
    PhotoStyle('vintage', '빈티지', Icons.photo_camera_back),
    PhotoStyle('movie_poster', '영화 포스터', Icons.movie),
    PhotoStyle('pop_art', '팝아트', Icons.palette),
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
    if (widget.tripId == null || _trip == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text('사진 꾸미기', style: AppTypography.subhead1),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: AppDimens.spacing16),
              Text(
                '여행을 먼저 선택해주세요',
                style: AppTypography.body1
                    .copyWith(color: AppColors.textSecondary),
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
        title: Text('사진 꾸미기', style: AppTypography.subhead1),
      ),
      body: Column(
        children: [
          // 여행 정보 헤더
          _buildTripHeader(),
          // 사진 목록
          Expanded(
            child: _photoItems.isEmpty
                ? _buildEmptyState()
                : _buildPhotoList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectPhotos,
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('사진 추가'),
      ),
    );
  }

  Widget _buildTripHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacing20,
        vertical: AppDimens.spacing12,
      ),
      color: AppColors.accent.withOpacity(0.05),
      child: Row(
        children: [
          const Icon(Icons.flight, size: 18, color: AppColors.accent),
          const SizedBox(width: AppDimens.spacing8),
          Expanded(
            child: Text(
              '${_trip!.destination} (${_trip!.period.displayString})',
              style: AppTypography.body2.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${_photoItems.length}/10',
            style: AppTypography.caption.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: GestureDetector(
        onTap: _selectPhotos,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                kIsWeb
                    ? Icons.upload_file
                    : Icons.add_photo_alternate_outlined,
                size: 40,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppDimens.spacing16),
            Text(
              '사진을 추가해서 AI로 꾸며보세요',
              style: AppTypography.body1.copyWith(color: AppColors.accent),
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              '최대 10장까지 추가 가능',
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoList() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimens.spacing16),
      itemCount: _photoItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimens.spacing16),
      itemBuilder: (context, index) => _buildPhotoCard(_photoItems[index], index),
    );
  }

  Widget _buildPhotoCard(_PhotoItem item, int index) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 영역: 원본 / 꾸며진 결과 비교
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.cardRadius),
            ),
            child: SizedBox(
              height: 220,
              child: item.isDecorated
                  ? _buildBeforeAfter(item)
                  : _buildOriginalOnly(item),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.spacing12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 파일명 & 상태
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.original.name,
                        style: AppTypography.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isSaved)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '저장됨',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (item.isDecorated && !item.isSaved)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '꾸미기 완료',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppDimens.spacing8),
                // 스타일 선택
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _styles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final style = _styles[i];
                      final isSelected = item.selectedStyle == style.id;
                      return GestureDetector(
                        onTap: item.isProcessing
                            ? null
                            : () {
                                setState(
                                    () => item.selectedStyle = style.id);
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accent.withOpacity(0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accent
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(style.icon,
                                  size: 14,
                                  color: isSelected
                                      ? AppColors.accent
                                      : AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                style.label,
                                style: AppTypography.caption.copyWith(
                                  color: isSelected
                                      ? AppColors.accent
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppDimens.spacing12),
                // 액션 버튼들
                Row(
                  children: [
                    // AI 꾸미기 버튼
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: (item.selectedStyle != null &&
                                  !item.isProcessing)
                              ? () => _decoratePhoto(item)
                              : null,
                          icon: item.isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(Icons.auto_awesome, size: 16),
                          label: Text(
                            item.isProcessing
                                ? '처리 중...'
                                : item.isDecorated
                                    ? '다시 꾸미기'
                                    : 'AI 꾸미기',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (item.isDecorated && !item.isSaved) ...[
                      const SizedBox(width: 8),
                      // 저장 버튼
                      SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: () => _savePhoto(item),
                          icon: const Icon(Icons.save_alt, size: 16),
                          label: const Text('저장',
                              style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    // 삭제 버튼
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: IconButton(
                        onPressed: item.isProcessing
                            ? null
                            : () => _removePhoto(index),
                        icon: const Icon(Icons.close, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalOnly(_PhotoItem item) {
    if (item.original.bytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(item.original.bytes!, fit: BoxFit.cover),
          if (item.isProcessing)
            Container(
              color: Colors.black38,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('AI가 꾸미는 중...',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.photo, size: 48, color: Colors.grey)),
    );
  }

  Widget _buildBeforeAfter(_PhotoItem item) {
    return Row(
      children: [
        // 원본
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.original.bytes != null)
                Image.memory(item.original.bytes!, fit: BoxFit.cover)
              else
                Container(color: Colors.grey.shade200),
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('BEFORE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        Container(width: 2, color: AppColors.surface),
        // 꾸며진 결과
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(item.decoratedBytes!, fit: BoxFit.cover),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('AFTER',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              if (item.isProcessing)
                Container(
                  color: Colors.black38,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectPhotos() async {
    final remaining = 10 - _photoItems.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최대 10장까지 추가할 수 있습니다'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      final List<XFile> files = await _picker.pickMultiImage(limit: remaining);
      if (files.isEmpty) return;

      final items = <_PhotoItem>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        items.add(_PhotoItem(
          original: _SelectedPhoto(
            name: file.name,
            bytes: bytes,
            path: kIsWeb ? null : file.path,
          ),
        ));
      }

      setState(() {
        _photoItems.addAll(items);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진 선택 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _decoratePhoto(_PhotoItem item) async {
    if (item.original.bytes == null || item.selectedStyle == null) return;

    setState(() => item.isProcessing = true);

    try {
      final result = await _apiService.decoratePhotoBytes(
        imageBytes: item.original.bytes!,
        fileName: item.original.name,
        style: item.selectedStyle!,
        tripId: widget.tripId,
      );

      final base64Data = result['result_image_base64'] as String?;
      if (base64Data != null && base64Data.isNotEmpty) {
        setState(() {
          item.decoratedBytes = base64Decode(base64Data);
          item.decoratedBase64 = base64Data;
          item.decoratedMimeType =
              result['result_mime_type'] as String? ?? 'image/jpeg';
          item.savedPhotoId = null; // 새로 꾸미면 저장 상태 초기화
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('꾸미기 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => item.isProcessing = false);
    }
  }

  Future<void> _savePhoto(_PhotoItem item) async {
    if (item.decoratedBase64 == null) return;

    try {
      final result = await _apiService.saveDecoratedPhoto(
        tripId: widget.tripId!,
        originalFilename: item.original.name,
        style: item.selectedStyle!,
        resultImageBase64: item.decoratedBase64!,
        resultMimeType: item.decoratedMimeType ?? 'image/jpeg',
      );

      final photoData = result['photo'] as Map<String, dynamic>?;
      if (photoData != null) {
        setState(() {
          item.savedPhotoId = photoData['id'] as String?;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진이 저장되었습니다!'),
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

  void _removePhoto(int index) {
    setState(() {
      _photoItems.removeAt(index);
    });
  }
}

class PhotoStyle {
  final String id;
  final String label;
  final IconData icon;

  PhotoStyle(this.id, this.label, this.icon);
}
