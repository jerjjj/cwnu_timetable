import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/color_palette.dart';
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
  static const _kIgnoredUpdateVersion = 'update.ignored.version';
  static const _kMigratedToSecure = 'auth.migrated_to_secure';
  static const _kCourseColors = 'timetable.course_colors';
  static const _kThemeMode = 'settings.theme_mode';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> _migrateIfNeeded() async {
    final prefs = await _preferences;
    final migrated = prefs.getBool(_kMigratedToSecure) ?? false;
    if (migrated) return;

    final password = prefs.getString(_kPassword);
    final jwxtPassword = prefs.getString(_kJwxtPassword);

    if (password != null && password.isNotEmpty) {
      try {
        await _secureStorage
            .write(key: _kPassword, value: password)
            .timeout(const Duration(seconds: 5));
        await prefs.remove(_kPassword);
      } catch (_) {}
    }

    if (jwxtPassword != null && jwxtPassword.isNotEmpty) {
      try {
        await _secureStorage
            .write(key: _kJwxtPassword, value: jwxtPassword)
            .timeout(const Duration(seconds: 5));
        await prefs.remove(_kJwxtPassword);
      } catch (_) {}
    }

    await prefs.setBool(_kMigratedToSecure, true);
  }

  static Future<String> _readSecure(String key) async {
    try {
      return await _secureStorage
              .read(key: key)
              .timeout(const Duration(seconds: 3)) ??
          '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> _writeSecure(String key, String value) async {
    try {
      await _secureStorage
          .write(key: key, value: value)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  static Future<void> _deleteSecure(String key) async {
    try {
      await _secureStorage.delete(key: key).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  static Future<bool> shouldShowWelcome() async {
    final prefs = await _preferences;
    return !(prefs.getBool(_kWelcomeCompleted) ?? false);
  }

  static Future<void> markWelcomeCompleted() async {
    final prefs = await _preferences;
    await prefs.setBool(_kWelcomeCompleted, true);
  }

  static Future<void> save(AuthSession session) async {
    final prefs = await _preferences;
    await prefs.setString(_kUsername, session.username);
    await _writeSecure(_kPassword, session.password);
    await _writeSecure(_kJwxtPassword, session.jwxtPassword);
  }

  static Future<AuthSession?> load() async {
    await _migrateIfNeeded();

    final prefs = await _preferences;
    final username = prefs.getString(_kUsername)?.trim() ?? '';
    final password = await _readSecure(_kPassword);
    final jwxtPassword = await _readSecure(_kJwxtPassword);

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
    final prefs = await _preferences;
    await prefs.remove(_kUsername);
    await _deleteSecure(_kPassword);
    await _deleteSecure(_kJwxtPassword);
    await prefs.remove(_kCachedRecords);
    await prefs.remove(_kLastSyncAt);
    await prefs.remove(_kIgnoredUpdateVersion);
  }

  static Future<void> markUpdateVersionIgnored(String version) async {
    final prefs = await _preferences;
    await prefs.setString(_kIgnoredUpdateVersion, version.trim());
  }

  static Future<String?> loadIgnoredUpdateVersion() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_kIgnoredUpdateVersion)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  static Future<void> saveCachedRecords(List<CourseRecord> records) async {
    final prefs = await _preferences;
    final encoded = jsonEncode(records.map((e) => e.toJson()).toList());
    await prefs.setString(_kCachedRecords, encoded);
    await _saveCourseColors(records);
  }

  static Future<void> _saveCourseColors(List<CourseRecord> records) async {
    final prefs = await _preferences;
    final palette = ColorPalette();
    final colorMap = <String, int>{};
    final courseNames = records.map((r) => r.courseName.trim()).toSet();
    for (final name in courseNames) {
      if (name.isNotEmpty) {
        colorMap[name] = palette.colorFor(name).toARGB32();
      }
    }
    final json = jsonEncode(colorMap);
    await prefs.setString(_kCourseColors, json);
    // ignore: avoid_print
    print('Saved ${colorMap.length} course colors');
  }

  static Future<void> markTimetableSyncedNow() async {
    final prefs = await _preferences;
    await prefs.setString(_kLastSyncAt, DateTime.now().toIso8601String());
  }

  static Future<DateTime?> loadLastTimetableSyncAt() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_kLastSyncAt);
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<bool> shouldAutoRefreshTimetable({
    Duration minInterval = const Duration(hours: 12),
  }) async {
    final lastSyncAt = await loadLastTimetableSyncAt();
    if (lastSyncAt == null) return true;

    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final lastSyncDateNormalized = DateTime(
      lastSyncAt.year,
      lastSyncAt.month,
      lastSyncAt.day,
    );

    if (todayNormalized != lastSyncDateNormalized) return true;

    return DateTime.now().difference(lastSyncAt) >= minInterval;
  }

  static Future<bool> shouldRefreshTimetableForWidget() async {
    final lastWidgetSyncAt = await _loadLastWidgetSyncAt();
    if (lastWidgetSyncAt == null) return true;
    return DateTime.now().difference(lastWidgetSyncAt) >=
        const Duration(minutes: 1);
  }

  static Future<void> markWidgetSyncedNow() async {
    final prefs = await _preferences;
    await prefs.setString(_kLastWidgetSyncAt, DateTime.now().toIso8601String());
  }

  static Future<DateTime?> _loadLastWidgetSyncAt() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_kLastWidgetSyncAt);
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<bool> isWidgetSyncRequested() async {
    final prefs = await _preferences;
    return prefs.getBool('flutter.timetable.widget_sync_requested') ?? false;
  }

  static Future<void> clearWidgetSyncRequest() async {
    final prefs = await _preferences;
    await prefs.remove('flutter.timetable.widget_sync_requested');
  }

  static List<CourseRecord>? _cachedRecords;

  static Future<List<CourseRecord>> loadCachedRecords() async {
    _cachedRecords ??= await _loadCachedRecordsFromDisk();
    return _cachedRecords!;
  }

  static Future<List<CourseRecord>> _loadCachedRecordsFromDisk() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_kCachedRecords);
    if (raw == null || raw.trim().isEmpty) return <CourseRecord>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <CourseRecord>[];
      return decoded
          .whereType<Map>()
          .map((e) => CourseRecord.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return <CourseRecord>[];
    }
  }

  static void invalidateRecordsCache() {
    _cachedRecords = null;
  }

  static DateTime defaultTermStartDate({DateTime? now}) {
    final current = now ?? DateTime.now();
    return DateTime(current.year, 3, 2);
  }

  static Future<void> saveTermStartDate(DateTime date) async {
    final prefs = await _preferences;
    final normalized = DateTime(date.year, date.month, date.day);
    await prefs.setString(_kTermStartDate, normalized.toIso8601String());
  }

  static Future<DateTime> loadTermStartDate() async {
    final prefs = await _preferences;
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

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await _preferences;
    await prefs.setInt(_kThemeMode, mode.index);
  }

  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await _preferences;
    final index = prefs.getInt(_kThemeMode);
    if (index == null || index < 0 || index >= ThemeMode.values.length) {
      return ThemeMode.system;
    }
    return ThemeMode.values[index];
  }
}
