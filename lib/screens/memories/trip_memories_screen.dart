import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../models/trip.dart';
import '../../models/decorated_photo.dart';
import '../../providers/trip_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

/// 여행 추억 갤러리 화면
class TripMemoriesScreen extends StatefulWidget {
  final String tripId;

  const TripMemoriesScreen({super.key, required this.tripId});

  @override
  State<TripMemoriesScreen> createState() => _TripMemoriesScreenState();
}

class _TripMemoriesScreenState extends State<TripMemoriesScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  Trip? _trip;
  List<DecoratedPhoto> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tripProvider = context.read<TripProvider>();
    _trip = tripProvider.getTripById(widget.tripId);

    setState(() => _isLoading = true);
    try {
      // 로컬 저장소에서 우선 로드
      _photos = await _storageService.getPhotosByTripId(widget.tripId);
    } catch (_) {
      _photos = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 앱바 with 여행 이미지
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _trip != null ? '${_trip!.destination} 추억' : '추억 갤러리',
                style: const TextStyle(
                  fontFamily: 'Noto Sans KR',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.accent.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 40, color: Colors.white54),
                      if (_trip != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _trip!.period.displayString,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 콘텐츠
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_photos.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            _buildPhotoGrid(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: AppDimens.spacing16),
          Text(
            '아직 꾸며진 사진이 없어요',
            style: AppTypography.subhead2
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spacing8),
          Text(
            '사진을 추가해서 AI로 꾸며보세요!',
            style:
                AppTypography.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.spacing24),
          ElevatedButton.icon(
            onPressed: () =>
                context.push(AppRoutes.photoDecorator, extra: widget.tripId),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('사진 꾸미러 가기'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(AppDimens.spacing12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildPhotoTile(_photos[index]),
          childCount: _photos.length,
        ),
      ),
    );
  }

  Widget _buildPhotoTile(DecoratedPhoto photo) {
    final bytes = base64Decode(photo.resultImageBase64);
    return GestureDetector(
      onTap: () => _showPhotoDetail(photo, bytes),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          child: Column(
            children: [
              Expanded(
                child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                color: AppColors.surface,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        photo.styleLabel,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _confirmDelete(photo),
                      child: Icon(Icons.delete_outline,
                          size: 16, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoDetail(DecoratedPhoto photo, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
              ),
              child: Row(
                children: [
                  Text(photo.styleLabel,
                      style: AppTypography.body2
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      photo.originalFilename,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDelete(photo);
                    },
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppColors.error,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(DecoratedPhoto photo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사진 삭제'),
        content: const Text('이 꾸며진 사진을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePhoto(photo);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePhoto(DecoratedPhoto photo) async {
    try {
      // 로컬 삭제
      await _storageService.deletePhoto(photo.id);
      // 백엔드 삭제 (실패해도 무시)
      try {
        await _apiService.deleteDecoratedPhoto(photo.id);
      } catch (_) {}

      setState(() {
        _photos.removeWhere((p) => p.id == photo.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진이 삭제되었습니다'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
