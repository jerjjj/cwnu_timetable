import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import '../models/course_record.dart';

class SessionStore {
  static const _kUsername = 'auth.username';
  static const _kPassword = 'auth.password';
  static const _kJwxtPassword = 'auth.jwxt_password';
  static const _kCachedRecords = 'timetable.cached_records';
  static const _kLastSyncAt = 'timetable.last_sync_at';
  static const _kLastWidgetSyncAt = 'timetable.last_widget_sync_at';
  static const _kTermStartDate = 'settings.term_start_date';
  static const _kWelcomeCompleted = 'app.welcome_completed';
  static const _kIgnoredUpdateVersion = 'update.ignored_version';

  static Future<bool> shouldShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kWelcomeCompleted) ?? false);
  }

  static Future<void> markWelcomeCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWelcomeCompleted, true);
  }

  static Future<void> save(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsername, session.username);
    await prefs.setString(_kPassword, session.password);
    await prefs.setString(_kJwxtPassword, session.jwxtPassword);
  }

  static Future<AuthSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_kUsername)?.trim() ?? '';
    final password = prefs.getString(_kPassword) ?? '';
    final jwxtPassword = prefs.getString(_kJwxtPassword) ?? '';
    if (username.isEmpty || password.isEmpty || jwxtPassword.isEmpty) {
      return null;
    }
    return AuthSession(
      username: username,
      password: password,
      jwxtPassword: jwxtPassword,
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUsername);
    await prefs.remove(_kPassword);
    await prefs.remove(_kJwxtPassword);
    await prefs.remove(_kCachedRecords);
    await prefs.remove(_kLastSyncAt);
    await prefs.remove(_kIgnoredUpdateVersion);
  }

  static Future<void> markUpdateVersionIgnored(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIgnoredUpdateVersion, version.trim());
  }

  static Future<String?> loadIgnoredUpdateVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kIgnoredUpdateVersion)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  static Future<void> saveCachedRecords(List<CourseRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(records.map((e) => e.toJson()).toList());
    await prefs.setString(_kCachedRecords, encoded);
  }

  static Future<void> markTimetableSyncedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastSyncAt, DateTime.now().toIso8601String());
  }

  static Future<DateTime?> loadLastTimetableSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLastSyncAt);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static Future<bool> shouldAutoRefreshTimetable({
    Duration minInterval = const Duration(hours: 12),
  }) async {
    final lastSyncAt = await loadLastTimetableSyncAt();
    if (lastSyncAt == null) {
      return true;
    }

    // 检查是否是新的一天（每天第一次打开时自动更新）
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final lastSyncDateNormalized = DateTime(
      lastSyncAt.year,
      lastSyncAt.month,
      lastSyncAt.day,
    );

    if (todayNormalized != lastSyncDateNormalized) {
      return true;
    }

    // 检查是否超过12小时（半天更新一次）
    return DateTime.now().difference(lastSyncAt) >= minInterval;
  }

  static Future<bool> shouldRefreshTimetableForWidget() async {
    final lastWidgetSyncAt = await _loadLastWidgetSyncAt();
    if (lastWidgetSyncAt == null) {
      return true;
    }
    // 小组件每次显示都应该同步，但避免频繁重复（间隔超过1分钟才再次同步）
    return DateTime.now().difference(lastWidgetSyncAt) >=
        const Duration(minutes: 1);
  }

  static Future<void> markWidgetSyncedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastWidgetSyncAt, DateTime.now().toIso8601String());
  }

  static Future<DateTime?> _loadLastWidgetSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLastWidgetSyncAt);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static Future<bool> isWidgetSyncRequested() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('flutter.timetable.widget_sync_requested') ?? false;
  }

  static Future<void> clearWidgetSyncRequest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('flutter.timetable.widget_sync_requested');
  }

  static Future<List<CourseRecord>> loadCachedRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCachedRecords);
    if (raw == null || raw.trim().isEmpty) {
      return <CourseRecord>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <CourseRecord>[];
      }
      return decoded
          .whereType<Map>()
          .map((e) => CourseRecord.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return <CourseRecord>[];
    }
  }

  static DateTime defaultTermStartDate({DateTime? now}) {
    final current = now ?? DateTime.now();
    return DateTime(current.year, 3, 2);
  }

  static Future<void> saveTermStartDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = DateTime(date.year, date.month, date.day);
    await prefs.setString(_kTermStartDate, normalized.toIso8601String());
  }

  static Future<DateTime> loadTermStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTermStartDate);
    if (raw == null || raw.trim().isEmpty) {
      final fallback = defaultTermStartDate();
      await saveTermStartDate(fallback);
      return fallback;
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      final fallback = defaultTermStartDate();
      await saveTermStartDate(fallback);
      return fallback;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
