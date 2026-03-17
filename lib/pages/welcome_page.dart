import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FB), Color(0xFFD4E8F8), Color(0xFFEAF6FF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Center(
                  child: Image.asset(
                    'assets/cwnu_badge_red.png',
                    height: 112,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  '欢迎使用稀饭课表',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D2B3A),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '专为西华师大学子设计的课表软件',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5A6878),
                  ),
                ),
                const Spacer(flex: 3),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 220,
                    height: 52,
                    child: FilledButton(
                      onPressed: onStart,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        elevation: 4,
                        backgroundColor: const Color(0xFF1D5F9A),
                      ),
                      child: const Text(
                        '开始使用',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
