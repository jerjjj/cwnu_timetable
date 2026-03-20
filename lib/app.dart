import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/app_bootstrap_page.dart';
import 'providers/app_providers.dart';

class CwnuTimetableApp extends ConsumerWidget {
  const CwnuTimetableApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: '稀饭课表',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D5F9A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D5F9A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AppBootstrapPage(),
    );
  }
}
