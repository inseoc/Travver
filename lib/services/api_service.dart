import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/models.dart';

/// 미디어 파일 데이터 (bytes 기반, 웹 호환)
class MediaFile {
  final Uint8List bytes;
  final String name;
  final bool isVideo;

  MediaFile({required this.bytes, required this.name, this.isVideo = false});
}

/// API 서비스 - 백엔드 통신
class ApiService {
  static const String baseUrl = 'http://localhost:8000/api';

  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    // 인터셉터 추가 (로깅, 에러 처리)
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('API Request: ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('API Response: ${response.statusCode}');
          return handler.next(response);
        },
        onError: (error, handler) {
          print('API Error: ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  /// AI 여행 일정 생성 요청
  Future<Trip> generateTravelPlan({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required int travelers,
    required int budget,
    required List<String> styles,
    String? accommodationLocation,
    String? customPreference,
  }) async {
    try {
      final data = {
        'destination': destination,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'travelers': travelers,
        'budget': budget,
        'styles': styles,
      };

      // 선택적 필드 추가
      if (accommodationLocation != null && accommodationLocation.isNotEmpty) {
        data['accommodation_location'] = accommodationLocation;
      }
      if (customPreference != null && customPreference.isNotEmpty) {
        data['custom_preference'] = customPreference;
      }

      final response = await _dio.post(
        '/v1/agent/travel-plan',
        data: data,
        options: Options(
          // AI 일정 생성은 시간이 오래 걸릴 수 있으므로 타임아웃 연장
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      // API 응답에서 trip 필드 추출
      final responseData = response.data;
      if (responseData['trip'] != null) {
        return Trip.fromJson(responseData['trip']);
      }
      return Trip.fromJson(responseData);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// AI 컨설턴트 채팅 요청
  Future<String> sendChatMessage({
    required String message,
    required List<ChatMessage> history,
    String? tripId,
  }) async {
    try {
      final response = await _dio.post(
        '/agent/consultant',
        data: {
          'message': message,
          'history': history.map((m) => m.toJson()).toList(),
          'trip_id': tripId,
        },
      );

      return response.data['response'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 스트리밍 채팅 요청 (Server-Sent Events)
  Stream<String> streamChatMessage({
    required String message,
    required List<ChatMessage> history,
    String? tripId,
  }) async* {
    try {
      final response = await _dio.post(
        '/agent/consultant/stream',
        data: {
          'message': message,
          'history': history.map((m) => m.toJson()).toList(),
          'trip_id': tripId,
        },
        options: Options(
          responseType: ResponseType.stream,
        ),
      );

      final stream = response.data.stream as Stream<List<int>>;
      await for (final chunk in stream) {
        final text = String.fromCharCodes(chunk);
        yield text;
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 사진 꾸미기 API
  Future<String> decoratePhoto({
    required String imagePath,
    required String style,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath),
        'style': style,
      });

      final response = await _dio.post(
        '/v1/memories/photo',
        data: formData,
        options: Options(
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      return response.data['result_url'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 사진 꾸미기 API (bytes 기반 - 웹 지원)
  /// 반환값: {'result_url': String, 'result_image_base64': String?, 'result_mime_type': String?}
  Future<Map<String, dynamic>> decoratePhotoBytes({
    required Uint8List imageBytes,
    required String fileName,
    required String style,
    String? tripId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
          contentType: DioMediaType.parse(
            fileName.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg',
          ),
        ),
        'style': style,
        if (tripId != null) 'trip_id': tripId,
      });

      final response = await _dio.post(
        '/v1/memories/photo',
        data: formData,
        options: Options(
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      return {
        'result_url': response.data['result_url'] as String,
        'result_image_base64': response.data['result_image_base64'] as String?,
        'result_mime_type': response.data['result_mime_type'] as String?,
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 영상 생성 API
  Future<String> createVideo({
    required List<String> mediaPaths,
    required String style,
    required String music,
    required int duration,
  }) async {
    try {
      final formData = FormData();

      for (final path in mediaPaths) {
        formData.files.add(MapEntry(
          'media',
          await MultipartFile.fromFile(path),
        ));
      }

      formData.fields.addAll([
        MapEntry('style', style),
        MapEntry('music', music),
        MapEntry('duration', duration.toString()),
      ]);

      final response = await _dio.post(
        '/v1/memories/video',
        data: formData,
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      return response.data['result_url'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 영상 생성 API (bytes 기반 - 웹 지원)
  Future<String> createVideoBytes({
    required List<MediaFile> mediaFiles,
    required String style,
    required String music,
    required int duration,
    String? tripId,
  }) async {
    try {
      final formData = FormData();

      for (final media in mediaFiles) {
        final mimeType = media.isVideo
            ? (media.name.toLowerCase().endsWith('.mov')
                ? 'video/quicktime'
                : 'video/mp4')
            : (media.name.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg');

        formData.files.add(MapEntry(
          'media',
          MultipartFile.fromBytes(
            media.bytes,
            filename: media.name,
            contentType: DioMediaType.parse(mimeType),
          ),
        ));
      }

      formData.fields.addAll([
        MapEntry('style', style),
        MapEntry('music', music),
        MapEntry('duration', duration.toString()),
        if (tripId != null) MapEntry('trip_id', tripId),
      ]);

      final response = await _dio.post(
        '/v1/memories/video',
        data: formData,
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      return response.data['result_url'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 에러 처리
  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '서버 연결 시간이 초과되었습니다. 다시 시도해주세요.';
      case DioExceptionType.connectionError:
        return '네트워크 연결을 확인해주세요.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 400) {
          return '요청이 올바르지 않습니다.';
        } else if (statusCode == 401) {
          return '인증이 필요합니다.';
        } else if (statusCode == 500) {
          return '서버 오류가 발생했습니다.';
        }
        return '요청 처리 중 오류가 발생했습니다.';
      default:
        return '알 수 없는 오류가 발생했습니다.';
    }
  }
}
