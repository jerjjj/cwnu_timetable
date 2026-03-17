import 'package:flutter/material.dart';

import 'pages/app_bootstrap_page.dart';

class CwnuTimetableApp extends StatelessWidget {
  const CwnuTimetableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '稀饭课表',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D5F9A)),
      ),
      home: const AppBootstrapPage(),
    );
  }
}
