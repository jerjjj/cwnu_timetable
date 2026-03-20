import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../models/course_record.dart';
import '../services/session_store.dart';

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AsyncValue<AuthSession?>>(
      (ref) => AuthSessionNotifier(),
    );

class AuthSessionNotifier extends StateNotifier<AsyncValue<AuthSession?>> {
  AuthSessionNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final session = await SessionStore.load();
      state = AsyncValue.data(session);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(AuthSession session) async {
    state = const AsyncValue.loading();
    try {
      await SessionStore.save(session);
      state = AsyncValue.data(session);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await SessionStore.clear();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final coursesProvider =
    StateNotifierProvider<CoursesNotifier, AsyncValue<List<CourseRecord>>>(
      (ref) => CoursesNotifier(),
    );

class CoursesNotifier extends StateNotifier<AsyncValue<List<CourseRecord>>> {
  CoursesNotifier() : super(const AsyncValue.loading()) {
    _loadCached();
  }

  Future<void> _loadCached() async {
    try {
      final records = await SessionStore.loadCachedRecords();
      state = AsyncValue.data(records);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh(List<CourseRecord> records) async {
    SessionStore.invalidateRecordsCache();
    state = AsyncValue.data(records);
    await SessionStore.saveCachedRecords(records);
  }

  Future<void> reload() async {
    SessionStore.invalidateRecordsCache();
    try {
      final records = await SessionStore.loadCachedRecords();
      state = AsyncValue.data(records);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final termStartDateProvider =
    StateNotifierProvider<TermStartDateNotifier, DateTime>(
      (ref) => TermStartDateNotifier(),
    );

class TermStartDateNotifier extends StateNotifier<DateTime> {
  TermStartDateNotifier() : super(SessionStore.defaultTermStartDate()) {
    _load();
  }

  Future<void> _load() async {
    final date = await SessionStore.loadTermStartDate();
    state = date;
  }

  Future<void> update(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    await SessionStore.saveTermStartDate(normalized);
    state = normalized;
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final mode = await SessionStore.loadThemeMode();
    state = mode;
  }

  Future<void> update(ThemeMode mode) async {
    await SessionStore.saveThemeMode(mode);
    state = mode;
  }
}
