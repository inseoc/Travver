import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

/// 임시 파일에 영상을 저장하고 VideoPlayerController를 생성합니다.
Future<VideoPlayerController> createVideoController(Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/travver_preview.mp4');
  await file.writeAsBytes(bytes);
  return VideoPlayerController.file(file);
}

/// 영상을 기기 갤러리에 저장합니다.
Future<String> saveVideoToDevice(Uint8List bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final filePath = '${dir.path}/$filename';
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  // 갤러리에 저장
  final permission = await PhotoManager.requestPermissionExtend();
  if (!permission.isAuth) {
    throw Exception('갤러리 접근 권한이 필요합니다');
  }

  final asset = await PhotoManager.editor.saveVideo(file, title: filename);
  if (asset != null) {
    return asset.title ?? filename;
  }

  throw Exception('갤러리 저장에 실패했습니다');
}
