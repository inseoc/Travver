// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:video_player/video_player.dart';

/// Blob URL을 생성하고 VideoPlayerController를 만듭니다.
Future<VideoPlayerController> createVideoController(Uint8List bytes) async {
  final blob = html.Blob([bytes], 'video/mp4');
  final url = html.Url.createObjectUrlFromBlob(blob);
  return VideoPlayerController.networkUrl(Uri.parse(url));
}

/// 브라우저에서 영상을 다운로드합니다.
Future<String> saveVideoToDevice(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], 'video/mp4');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return filename;
}
