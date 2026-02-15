import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';
import '../../models/decorated_photo.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../app/routes.dart';

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
  final TextEditingController promptController = TextEditingController();
  String? appliedPrompt;
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
  final StorageService _storageService = StorageService();

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

    final hasUnsaved = _photoItems.any((p) => p.isDecorated && !p.isSaved);
    final allSaved = _photoItems.isNotEmpty &&
        _photoItems.every((p) => !p.isDecorated || p.isSaved) &&
        _photoItems.any((p) => p.isSaved);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('사진 꾸미기', style: AppTypography.subhead1),
        actions: [
          if (_photoItems.length < 10)
            TextButton.icon(
              onPressed: _selectPhotos,
              icon: const Icon(Icons.add_photo_alternate,
                  size: 20, color: AppColors.accent),
              label: Text(
                '사진 추가',
                style: AppTypography.body2.copyWith(color: AppColors.accent),
              ),
            ),
        ],
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
          // 하단 저장/갤러리 바
          if (hasUnsaved || allSaved) _buildBottomBar(hasUnsaved, allSaved),
        ],
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
                Icons.add_photo_alternate_outlined,
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
                // 프롬프트 입력
                TextField(
                  controller: item.promptController,
                  maxLength: 30,
                  enabled: !item.isProcessing,
                  decoration: const InputDecoration(
                    hintText: '원하는 스타일을 입력하세요',
                    hintStyle: TextStyle(fontSize: 13),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    counterText: '',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty && !item.isProcessing) {
                      _decoratePhoto(item);
                    }
                  },
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
                          onPressed: (!item.isProcessing)
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
                              : const Icon(Icons.auto_awesome, size: 16),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 원본
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.original.bytes != null)
                Image.memory(item.original.bytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity)
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
              Image.memory(item.decoratedBytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity),
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
            path: file.path,
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
    final prompt = item.promptController.text.trim();
    if (item.original.bytes == null || prompt.isEmpty) {
      if (prompt.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('스타일 프롬프트를 입력해주세요'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    setState(() => item.isProcessing = true);

    try {
      final result = await _apiService.decoratePhotoBytes(
        imageBytes: item.original.bytes!,
        fileName: item.original.name,
        prompt: prompt,
        tripId: widget.tripId,
      );

      final base64Data = result['result_image_base64'] as String?;
      if (base64Data != null && base64Data.isNotEmpty) {
        setState(() {
          item.decoratedBytes = base64Decode(base64Data);
          item.decoratedBase64 = base64Data;
          item.decoratedMimeType =
              result['result_mime_type'] as String? ?? 'image/jpeg';
          item.appliedPrompt = prompt;
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

  Future<void> _savePhoto(_PhotoItem item, {bool silent = false}) async {
    if (item.decoratedBase64 == null) return;

    try {
      // 기존 사진 개수로 번호 결정
      final existingCount = await _storageService.getPhotoCountByTripId(widget.tripId!);
      final displayName = 'Photo ${existingCount + 1}';

      // 백엔드에 저장 시도
      String? photoId;
      try {
        final result = await _apiService.saveDecoratedPhoto(
          tripId: widget.tripId!,
          originalFilename: item.original.name,
          prompt: item.appliedPrompt ?? item.promptController.text.trim(),
          resultImageBase64: item.decoratedBase64!,
          resultMimeType: item.decoratedMimeType ?? 'image/jpeg',
        );
        final photoData = result['photo'] as Map<String, dynamic>?;
        photoId = photoData?['id'] as String?;
      } catch (_) {
        // 백엔드 실패 시 로컬 ID 생성
      }

      photoId ??=
          'photo_${DateTime.now().millisecondsSinceEpoch}';

      // 로컬 저장 (항상)
      final photo = DecoratedPhoto(
        id: photoId,
        tripId: widget.tripId!,
        originalFilename: item.original.name,
        style: item.appliedPrompt ?? item.promptController.text.trim(),
        resultImageBase64: item.decoratedBase64!,
        resultMimeType: item.decoratedMimeType ?? 'image/jpeg',
        displayName: displayName,
        createdAt: DateTime.now(),
      );
      await _storageService.savePhoto(photo);

      setState(() {
        item.savedPhotoId = photoId;
      });

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진이 저장되었습니다!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
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

  Widget _buildBottomBar(bool hasUnsaved, bool allSaved) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacing16,
        AppDimens.spacing12,
        AppDimens.spacing16,
        AppDimens.spacing16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (hasUnsaved)
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingAll ? null : _saveAllPhotos,
                    icon: _isSavingAll
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_alt, size: 20),
                    label: Text(
                      _isSavingAll ? '저장 중...' : '모두 저장',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            if (hasUnsaved && allSaved) const SizedBox(width: 10),
            if (allSaved || !hasUnsaved)
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push(
                          AppRoutes.tripMemories, extra: widget.tripId);
                    },
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: const Text(
                      '추억 갤러리 보기',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isSavingAll = false;

  Future<void> _saveAllPhotos() async {
    final unsaved =
        _photoItems.where((p) => p.isDecorated && !p.isSaved).toList();
    if (unsaved.isEmpty) return;

    setState(() => _isSavingAll = true);

    int savedCount = 0;
    for (final item in unsaved) {
      try {
        await _savePhoto(item, silent: true);
        if (item.isSaved) savedCount++;
      } catch (_) {
        // 개별 실패는 무시하고 계속 진행
      }
    }

    if (mounted) {
      setState(() => _isSavingAll = false);
      if (savedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$savedCount장의 사진이 저장되었습니다!'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: '갤러리 보기',
              textColor: Colors.white,
              onPressed: () {
                context.push(AppRoutes.tripMemories, extra: widget.tripId);
              },
            ),
          ),
        );
      }
    }
  }
}
