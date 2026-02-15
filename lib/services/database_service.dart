import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/models.dart';

/// SQLite 데이터베이스 서비스
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  static const int _dbVersion = 1;
  static const String _dbName = 'travver.db';

  /// 데이터베이스 인스턴스 획득
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 데이터베이스 초기화
  Future<Database> _initDatabase() async {
    // Web 플랫폼: sqflite_common_ffi_web 팩토리 사용
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// 외래키 활성화
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// 스키마 생성 (Version 1)
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. app_config
    batch.execute('''
      CREATE TABLE app_config (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 2. trips
    batch.execute('''
      CREATE TABLE trips (
        id                     TEXT    PRIMARY KEY,
        destination            TEXT    NOT NULL,
        period_start           TEXT    NOT NULL,
        period_end             TEXT    NOT NULL,
        travelers              INTEGER NOT NULL DEFAULT 1,
        budget_estimated       INTEGER NOT NULL DEFAULT 0,
        budget_currency        TEXT    NOT NULL DEFAULT 'KRW',
        styles                 TEXT    NOT NULL DEFAULT '[]',
        custom_preference      TEXT,
        accommodation_location TEXT,
        status                 TEXT    NOT NULL DEFAULT 'upcoming',
        image_url              TEXT,
        created_at             TEXT    NOT NULL,
        updated_at             TEXT    NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_trips_status ON trips(status)');
    batch.execute('CREATE INDEX idx_trips_created_at ON trips(created_at)');

    // 3. daily_plans
    batch.execute('''
      CREATE TABLE daily_plans (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id TEXT    NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
        day     INTEGER NOT NULL,
        date    TEXT    NOT NULL,
        theme   TEXT    NOT NULL,
        UNIQUE(trip_id, day)
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_daily_plans_trip_id ON daily_plans(trip_id)');

    // 4. schedules
    batch.execute('''
      CREATE TABLE schedules (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        daily_plan_id  INTEGER NOT NULL REFERENCES daily_plans(id) ON DELETE CASCADE,
        order_index    INTEGER NOT NULL,
        time           TEXT    NOT NULL,
        place          TEXT    NOT NULL,
        category       TEXT    NOT NULL,
        duration_min   INTEGER NOT NULL,
        estimated_cost INTEGER NOT NULL DEFAULT 0,
        description    TEXT    NOT NULL DEFAULT '',
        latitude       REAL    NOT NULL,
        longitude      REAL    NOT NULL,
        image_url      TEXT,
        rating         REAL,
        place_id       TEXT,
        UNIQUE(daily_plan_id, order_index)
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_schedules_daily_plan_id ON schedules(daily_plan_id)');
    batch.execute(
        'CREATE INDEX idx_schedules_category ON schedules(category)');

    // 5. decorated_photos
    batch.execute('''
      CREATE TABLE decorated_photos (
        id                  TEXT PRIMARY KEY,
        trip_id             TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
        original_filename   TEXT NOT NULL,
        style               TEXT NOT NULL,
        result_image_base64 TEXT NOT NULL,
        result_mime_type    TEXT NOT NULL DEFAULT 'image/jpeg',
        created_at          TEXT NOT NULL
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_decorated_photos_trip_id ON decorated_photos(trip_id)');
    batch.execute(
        'CREATE INDEX idx_decorated_photos_created_at ON decorated_photos(created_at)');

    // 6. chat_messages
    batch.execute('''
      CREATE TABLE chat_messages (
        id           TEXT    PRIMARY KEY,
        trip_id      TEXT    REFERENCES trips(id) ON DELETE SET NULL,
        role         TEXT    NOT NULL,
        content      TEXT    NOT NULL,
        status       TEXT    NOT NULL DEFAULT 'sent',
        is_tool_call INTEGER NOT NULL DEFAULT 0,
        tool_name    TEXT,
        timestamp    TEXT    NOT NULL
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_chat_messages_trip_id ON chat_messages(trip_id)');
    batch.execute(
        'CREATE INDEX idx_chat_messages_timestamp ON chat_messages(timestamp)');

    // 초기 설정 삽입
    batch.insert('app_config', {'key': 'is_first_launch', 'value': 'true'});

    await batch.commit(noResult: true);
  }

  /// 스키마 업그레이드
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 향후 마이그레이션 처리
  }

  // ──────────────────────────────────────────────
  // app_config CRUD
  // ──────────────────────────────────────────────

  /// 설정 값 조회
  Future<String?> getConfig(String key) async {
    final db = await database;
    final result = await db.query(
      'app_config',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String;
  }

  /// 설정 값 저장 (upsert)
  Future<void> setConfig(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_config',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ──────────────────────────────────────────────
  // trips CRUD
  // ──────────────────────────────────────────────

  /// 모든 여행 조회 (daily_plans + schedules 포함)
  Future<List<Trip>> getAllTrips() async {
    final db = await database;
    final tripRows = await db.query('trips', orderBy: 'created_at DESC');

    final trips = <Trip>[];
    for (final row in tripRows) {
      trips.add(await _buildTripFromRow(db, row));
    }
    return trips;
  }

  /// 특정 여행 조회
  Future<Trip?> getTripById(String tripId) async {
    final db = await database;
    final rows = await db.query('trips', where: 'id = ?', whereArgs: [tripId]);
    if (rows.isEmpty) return null;
    return await _buildTripFromRow(db, rows.first);
  }

  /// 여행 저장 (upsert: trip + daily_plans + schedules)
  Future<void> saveTrip(Trip trip) async {
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // trips 테이블 upsert
      await txn.insert(
        'trips',
        {
          'id': trip.id,
          'destination': trip.destination,
          'period_start': trip.period.start.toIso8601String().split('T')[0],
          'period_end': trip.period.end.toIso8601String().split('T')[0],
          'travelers': trip.travelers,
          'budget_estimated': trip.budget.estimated,
          'budget_currency': trip.budget.currency,
          'styles': jsonEncode(trip.styles.map((s) => s.name).toList()),
          'custom_preference': trip.customPreference,
          'accommodation_location': trip.accommodationLocation,
          'status': trip.status.name,
          'image_url': trip.imageUrl,
          'created_at': trip.createdAt.toIso8601String(),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 기존 daily_plans 삭제 (cascade로 schedules도 삭제됨)
      await txn.delete('daily_plans',
          where: 'trip_id = ?', whereArgs: [trip.id]);

      // daily_plans + schedules 삽입
      for (final plan in trip.dailyPlans) {
        final dailyPlanId = await txn.insert('daily_plans', {
          'trip_id': trip.id,
          'day': plan.day,
          'date': plan.date.toIso8601String().split('T')[0],
          'theme': plan.theme,
        });

        for (final schedule in plan.schedules) {
          await txn.insert('schedules', {
            'daily_plan_id': dailyPlanId,
            'order_index': schedule.order,
            'time': schedule.time,
            'place': schedule.place,
            'category': schedule.category.name,
            'duration_min': schedule.durationMin,
            'estimated_cost': schedule.estimatedCost,
            'description': schedule.description,
            'latitude': schedule.location.lat,
            'longitude': schedule.location.lng,
            'image_url': schedule.imageUrl,
            'rating': schedule.rating,
            'place_id': schedule.placeId,
          });
        }
      }
    });
  }

  /// 여행 삭제 (cascade로 daily_plans, schedules 자동 삭제)
  Future<void> deleteTrip(String tripId) async {
    final db = await database;
    await db.delete('trips', where: 'id = ?', whereArgs: [tripId]);
  }

  /// 모든 여행 삭제
  Future<void> clearAllTrips() async {
    final db = await database;
    await db.delete('trips');
  }

  /// DB 행으로부터 Trip 객체 빌드
  Future<Trip> _buildTripFromRow(Database db, Map<String, dynamic> row) async {
    // daily_plans 조회
    final planRows = await db.query(
      'daily_plans',
      where: 'trip_id = ?',
      whereArgs: [row['id']],
      orderBy: 'day ASC',
    );

    final dailyPlans = <DailyPlan>[];
    for (final planRow in planRows) {
      // schedules 조회
      final scheduleRows = await db.query(
        'schedules',
        where: 'daily_plan_id = ?',
        whereArgs: [planRow['id']],
        orderBy: 'order_index ASC',
      );

      final schedules = scheduleRows.map((s) {
        return Schedule(
          order: s['order_index'] as int,
          time: s['time'] as String,
          place: s['place'] as String,
          category: PlaceCategory.fromString(s['category'] as String),
          durationMin: s['duration_min'] as int,
          estimatedCost: s['estimated_cost'] as int,
          description: s['description'] as String? ?? '',
          location: Location(
            lat: (s['latitude'] as num).toDouble(),
            lng: (s['longitude'] as num).toDouble(),
          ),
          imageUrl: s['image_url'] as String?,
          rating: s['rating'] != null ? (s['rating'] as num).toDouble() : null,
          placeId: s['place_id'] as String?,
        );
      }).toList();

      dailyPlans.add(DailyPlan(
        day: planRow['day'] as int,
        date: DateTime.parse(planRow['date'] as String),
        theme: planRow['theme'] as String,
        schedules: schedules,
      ));
    }

    // styles JSON 파싱
    final stylesJson = jsonDecode(row['styles'] as String) as List<dynamic>;
    final styles =
        stylesJson.map((s) => TravelStyle.fromString(s as String)).toList();

    return Trip(
      id: row['id'] as String,
      destination: row['destination'] as String,
      period: TripPeriod(
        start: DateTime.parse(row['period_start'] as String),
        end: DateTime.parse(row['period_end'] as String),
      ),
      travelers: row['travelers'] as int,
      budget: Budget(
        estimated: row['budget_estimated'] as int,
        currency: row['budget_currency'] as String,
      ),
      styles: styles,
      customPreference: row['custom_preference'] as String?,
      accommodationLocation: row['accommodation_location'] as String?,
      dailyPlans: dailyPlans,
      status: TripStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => TripStatus.upcoming,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
      imageUrl: row['image_url'] as String?,
    );
  }

  // ──────────────────────────────────────────────
  // decorated_photos CRUD
  // ──────────────────────────────────────────────

  /// 여행별 꾸며진 사진 조회
  Future<List<DecoratedPhoto>> getPhotosByTripId(String tripId) async {
    final db = await database;
    final rows = await db.query(
      'decorated_photos',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_buildPhotoFromRow).toList();
  }

  /// 꾸며진 사진 저장
  Future<void> savePhoto(DecoratedPhoto photo) async {
    final db = await database;
    await db.insert(
      'decorated_photos',
      {
        'id': photo.id,
        'trip_id': photo.tripId,
        'original_filename': photo.originalFilename,
        'style': photo.style,
        'result_image_base64': photo.resultImageBase64,
        'result_mime_type': photo.resultMimeType,
        'created_at': photo.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 꾸며진 사진 삭제
  Future<void> deletePhoto(String photoId) async {
    final db = await database;
    await db.delete('decorated_photos',
        where: 'id = ?', whereArgs: [photoId]);
  }

  /// 여행별 사진 개수 조회
  Future<int> getPhotoCountByTripId(String tripId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM decorated_photos WHERE trip_id = ?',
      [tripId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 모든 여행의 사진 개수를 Map으로 반환
  Future<Map<String, int>> getAllPhotoCountsByTrip() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT trip_id, COUNT(*) as cnt FROM decorated_photos GROUP BY trip_id',
    );
    final counts = <String, int>{};
    for (final row in rows) {
      counts[row['trip_id'] as String] = row['cnt'] as int;
    }
    return counts;
  }

  DecoratedPhoto _buildPhotoFromRow(Map<String, dynamic> row) {
    return DecoratedPhoto(
      id: row['id'] as String,
      tripId: row['trip_id'] as String,
      originalFilename: row['original_filename'] as String,
      style: row['style'] as String,
      resultImageBase64: row['result_image_base64'] as String,
      resultMimeType: row['result_mime_type'] as String? ?? 'image/jpeg',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  // ──────────────────────────────────────────────
  // chat_messages CRUD
  // ──────────────────────────────────────────────

  /// 여행별 채팅 메시지 조회
  Future<List<ChatMessage>> getChatMessagesByTripId(String? tripId) async {
    final db = await database;
    final rows = await db.query(
      'chat_messages',
      where: tripId != null ? 'trip_id = ?' : 'trip_id IS NULL',
      whereArgs: tripId != null ? [tripId] : null,
      orderBy: 'timestamp ASC',
    );
    return rows.map(_buildChatMessageFromRow).toList();
  }

  /// 채팅 메시지 저장
  Future<void> saveChatMessage(ChatMessage message, {String? tripId}) async {
    final db = await database;
    await db.insert(
      'chat_messages',
      {
        'id': message.id,
        'trip_id': tripId,
        'role': message.role.name,
        'content': message.content,
        'status': message.status.name,
        'is_tool_call': message.isToolCall ? 1 : 0,
        'tool_name': message.toolName,
        'timestamp': message.timestamp.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 여행별 채팅 메시지 삭제
  Future<void> deleteChatMessagesByTripId(String? tripId) async {
    final db = await database;
    if (tripId != null) {
      await db.delete('chat_messages',
          where: 'trip_id = ?', whereArgs: [tripId]);
    } else {
      await db.delete('chat_messages', where: 'trip_id IS NULL');
    }
  }

  ChatMessage _buildChatMessageFromRow(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'] as String,
      role: MessageRole.values.firstWhere(
        (r) => r.name == row['role'],
        orElse: () => MessageRole.user,
      ),
      content: row['content'] as String,
      timestamp: DateTime.parse(row['timestamp'] as String),
      status: MessageStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => MessageStatus.sent,
      ),
      isToolCall: (row['is_tool_call'] as int) == 1,
      toolName: row['tool_name'] as String?,
    );
  }

  // ──────────────────────────────────────────────
  // 마이그레이션: SharedPreferences → SQLite
  // ──────────────────────────────────────────────

  /// SharedPreferences 데이터를 SQLite로 마이그레이션
  Future<bool> get isMigrated async {
    final value = await getConfig('migrated_from_prefs');
    return value == 'true';
  }

  Future<void> markMigrated() async {
    await setConfig('migrated_from_prefs', 'true');
  }

  /// 데이터베이스 닫기
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
