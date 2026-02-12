import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../app/theme.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';
import '../../services/api_service.dart';
import '../../utils/video_helper.dart';

/// 나만의 영상 화면
/// - AI로 시네마틱 영상 생성
/// - Google Gemini Veo 3.1 사용
/// - 모바일: 갤러리에서 미디어 선택, 웹: 파일 업로드
class VideoCreatorScreen extends StatefulWidget {
  final String? tripId;

  const VideoCreatorScreen({super.key, this.tripId});

  @override
  State<VideoCreatorScreen> createState() => _VideoCreatorScreenState();
}

class _SelectedMedia {
  final String name;
  final Uint8List? bytes;
  final String? path;
  final bool isVideo;

  _SelectedMedia({
    required this.name,
    this.bytes,
    this.path,
    this.isVideo = false,
  });
}

class _VideoCreatorScreenState extends State<VideoCreatorScreen> {
  final List<_SelectedMedia> _selectedMedia = [];
  String? _selectedStyle;
  String? _selectedMusic;
  int _duration = 30;
  bool _isProcessing = false;
  Trip? _trip;
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();

  // 생성 결과
  Uint8List? _resultVideoBytes;
  String? _resultStyle;

  // 영상 플레이어
  VideoPlayerController? _videoController;
  bool _isVideoReady = false;
  bool _isSaving = false;

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
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _disposeVideoPlayer() {
    _videoController?.dispose();
    _videoController = null;
    _isVideoReady = false;
  }

  Future<void> _initVideoPlayer() async {
    if (_resultVideoBytes == null) return;
    try {
      _videoController = await createVideoController(_resultVideoBytes!);
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      if (mounted) {
        setState(() => _isVideoReady = true);
      }
    } catch (e) {
      debugPrint('Video player init error: $e');
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

    // 결과 화면
    if (_resultVideoBytes != null) {
      return _buildResultScreen();
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
          kIsWeb
              ? '이미지 또는 동영상 파일을 업로드하세요 (최대 20개)'
              : '${_trip!.destination} 여행 기간(${_trip!.period.displayString})에 촬영된 갤러리 미디어만 선택할 수 있습니다',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppDimens.spacing12),

        // 미디어 선택 버튼 (웹: 사진/영상 분리)
        if (kIsWeb) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectedMedia.length < 20 ? _selectPhotosFromPicker : null,
                  icon: const Icon(Icons.photo_outlined, size: 18),
                  label: const Text('사진 추가'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    side: BorderSide(color: AppColors.info.withOpacity(0.5)),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spacing8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectedMedia.length < 20 ? _selectVideoFromPicker : null,
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('영상 추가'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    side: BorderSide(color: AppColors.info.withOpacity(0.5)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacing12),
        ],

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
      onTap: _selectPhotosFromPicker,
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
              child: Icon(
                kIsWeb ? Icons.upload_file : Icons.add_a_photo_outlined,
                size: 28,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: AppDimens.spacing8),
            Text(
              kIsWeb ? '클릭하여 미디어 업로드' : '미디어를 선택하세요',
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
            final media = _selectedMedia[index];
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: media.bytes != null && !media.isVideo
                        ? Image.memory(
                            media.bytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  media.isVideo ? Icons.videocam : Icons.photo,
                                  color: Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  media.name,
                                  style: AppTypography.caption.copyWith(fontSize: 7),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                if (media.isVideo)
                  Positioned(
                    bottom: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Icon(Icons.play_arrow, size: 10, color: Colors.white),
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
        if (_selectedMedia.length < 20 && !kIsWeb)
          Positioned(
            right: AppDimens.spacing8,
            bottom: AppDimens.spacing8,
            child: FloatingActionButton.small(
              onPressed: _selectPhotosFromPicker,
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

  Future<void> _selectPhotosFromPicker() async {
    final remaining = 20 - _selectedMedia.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최대 20개까지 선택할 수 있습니다'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      final List<XFile> files = await _picker.pickMultiImage(
        limit: remaining,
      );

      if (files.isEmpty) return;

      final media = <_SelectedMedia>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        media.add(_SelectedMedia(
          name: file.name,
          bytes: bytes,
          path: kIsWeb ? null : file.path,
          isVideo: false,
        ));
      }

      setState(() {
        _selectedMedia.addAll(media);
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

  Future<void> _selectVideoFromPicker() async {
    final remaining = 20 - _selectedMedia.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최대 20개까지 선택할 수 있습니다'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);

      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _selectedMedia.add(_SelectedMedia(
          name: file.name,
          bytes: bytes,
          path: kIsWeb ? null : file.path,
          isVideo: true,
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('영상 선택 실패: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _createVideo() async {
    setState(() => _isProcessing = true);

    try {
      final mediaFiles = _selectedMedia
          .where((m) => m.bytes != null)
          .map((m) => MediaFile(
                bytes: m.bytes!,
                name: m.name,
                isVideo: m.isVideo,
              ))
          .toList();

      final result = await _apiService.createVideoBytes(
        mediaFiles: mediaFiles,
        style: _selectedStyle!,
        music: _selectedMusic!,
        duration: _duration,
        tripId: widget.tripId,
      );

      final base64Data = result['result_video_base64'] as String?;
      if (base64Data != null && base64Data.isNotEmpty) {
        final bytes = base64Decode(base64Data);
        setState(() {
          _resultVideoBytes = bytes;
          _resultStyle = result['style'] as String?;
        });
        await _initVideoPlayer();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('영상이 생성되었지만 데이터를 받지 못했습니다'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
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

  String _getStyleLabel(String? styleId) {
    final style = _styles.where((s) => s.id == styleId).firstOrNull;
    return style?.label ?? '영상';
  }

  Widget _buildResultScreen() {
    final fileSizeMB = (_resultVideoBytes!.length / (1024 * 1024)).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('영상 완성', style: AppTypography.subhead1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _disposeVideoPlayer();
            setState(() {
              _resultVideoBytes = null;
              _resultStyle = null;
            });
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spacing16),
                child: Column(
                  children: [
                    // 영상 미리보기 플레이어
                    _buildVideoPlayer(),

                    const SizedBox(height: AppDimens.spacing16),

                    Text(
                      '${_trip?.destination ?? ""} ${_getStyleLabel(_resultStyle)}',
                      style: AppTypography.subhead1,
                    ),
                    const SizedBox(height: AppDimens.spacing4),
                    Text(
                      '영상이 완성되었습니다',
                      style: AppTypography.body2.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppDimens.spacing16),

                    // 영상 정보 카드
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimens.spacing16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppDimens.cardRadius),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(Icons.movie_outlined, '스타일',
                              _getStyleLabel(_resultStyle)),
                          const Divider(height: 20),
                          _buildInfoRow(Icons.timer_outlined, '길이',
                              '$_duration초'),
                          const Divider(height: 20),
                          _buildInfoRow(Icons.sd_storage_outlined, '크기',
                              '${fileSizeMB}MB'),
                          const Divider(height: 20),
                          _buildInfoRow(Icons.high_quality_outlined, '포맷',
                              'MP4'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 하단 버튼
          Container(
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveVideoToDevice,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download),
                      label: Text(_isSaving ? '저장 중...' : '기기에 저장'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacing8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _disposeVideoPlayer();
                        setState(() {
                          _resultVideoBytes = null;
                          _resultStyle = null;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('새 영상 만들기'),
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

  Widget _buildVideoPlayer() {
    if (!_isVideoReady || _videoController == null) {
      // 영상 로딩 중
      return Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text(
                '영상을 준비하고 있습니다...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 영상 영역
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                  // 재생/일시정지 오버레이
                  if (!_videoController!.value.isPlaying)
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            // 프로그레스 바
            VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.info,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: AppDimens.spacing12),
        Text(label, style: AppTypography.body2.copyWith(
          color: AppColors.textSecondary,
        )),
        const Spacer(),
        Text(value, style: AppTypography.body2.copyWith(
          fontWeight: FontWeight.w600,
        )),
      ],
    );
  }

  Future<void> _saveVideoToDevice() async {
    if (_resultVideoBytes == null) return;

    setState(() => _isSaving = true);

    try {
      final destination = _trip?.destination ?? 'travver';
      final style = _resultStyle ?? 'video';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${destination}_${style}_$timestamp.mp4';

      await saveVideoToDevice(_resultVideoBytes!, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kIsWeb ? '다운로드가 시작되었습니다' : '갤러리에 저장되었습니다'),
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
