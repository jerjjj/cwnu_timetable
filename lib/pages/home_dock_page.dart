import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../models/course_record.dart';
import '../providers/app_providers.dart';
import '../services/session_store.dart';
import 'login_page.dart';
import 'settings_tab_page.dart';
import 'timetable_page.dart';
import 'today_page.dart';

class HomeDockPage extends ConsumerStatefulWidget {
  const HomeDockPage({
    super.key,
    required this.session,
    required this.initialRecords,
  });

  final AuthSession session;
  final List<CourseRecord> initialRecords;

  @override
  ConsumerState<HomeDockPage> createState() => _HomeDockPageState();
}

class _HomeDockPageState extends ConsumerState<HomeDockPage> {
  final _todayKey = GlobalKey<TodayPageState>();
  final _timetableKey = GlobalKey<TimetablePageState>();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkWidgetSyncRequest();
  }

  Future<void> _checkWidgetSyncRequest() async {
    final widgetSyncRequested = await SessionStore.isWidgetSyncRequested();
    if (widgetSyncRequested && mounted) {
      await SessionStore.clearWidgetSyncRequest();
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _timetableKey.currentState?.checkAndRefreshForWidget();
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authSessionProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TodayPage(key: _todayKey, initialRecords: widget.initialRecords),
          TimetablePage(
            key: _timetableKey,
            session: widget.session,
            initialRecords: widget.initialRecords,
          ),
          SettingsTabPage(
            onTermStartDateChanged: () {
              _todayKey.currentState?.reloadTermStartDate();
              _timetableKey.currentState?.reloadTermStartDate();
            },
            onLogout: _logout,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == 0) {
            _todayKey.currentState?.reloadFromCache();
          }
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_week_outlined),
            selectedIcon: Icon(Icons.view_week),
            label: '本周',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
