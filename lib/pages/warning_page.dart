import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class WarningPage extends StatefulWidget {
  const WarningPage({super.key, required this.onAcknowledge});

  final Future<void> Function() onAcknowledge;

  @override
  State<WarningPage> createState() => _WarningPageState();
}

class _WarningPageState extends State<WarningPage> {
  static final Uri _helpUri = Uri.parse('https://www.kdocs.cn/l/clr9aN3uXwoF');
  int _secondsLeft = 15;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        return;
      }
      if (_secondsLeft <= 1) {
        setState(() {
          _secondsLeft = 0;
        });
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft -= 1;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _openHelpLink() async {
    await launchUrl(_helpUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleAcknowledge() async {
    if (_secondsLeft > 0) {
      return;
    }
    await widget.onAcknowledge();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tagColor = const Color(0xFFFF5252);
    final normalColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                '使用前须知',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHigh
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SingleChildScrollView(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          color: normalColor,
                        ),
                        children: [
                          TextSpan(
                            text: '[注意！！！]',
                            style: TextStyle(
                              color: tagColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text:
                                '：本软件处于早期测试阶段，如有因为bug导致的课程缺席等，本人概不负责（理论上不会出错），如发现错误，可通过邮件联系我：wuzhijun@jerjjj.cn\n\n',
                            style: TextStyle(
                              color: normalColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: '[注意！！]',
                            style: TextStyle(
                              color: tagColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text:
                                '：本软件的联网功能仅用于西华师大教务系统的课表获取，不会有任何非官方的中转服务器，本软件也不会收集你的任何个人信息\n\n',
                            style: TextStyle(
                              color: normalColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: '[提醒]',
                            style: TextStyle(
                              color: tagColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text:
                                '：西华师大的教务系统密码与信息门户密码不同，教务系统密码为系统自动生成并不可以修改，所以请前往：',
                            style: TextStyle(
                              color: normalColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: 'https://www.kdocs.cn/l/clr9aN3uXwoF',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = _openHelpLink,
                          ),
                          TextSpan(
                            text: ' 查看获取教务系统密码的方法并复制下来，登录页面直接填写即可\n\n',
                            style: TextStyle(
                              color: normalColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: '[注意]',
                            style: TextStyle(
                              color: tagColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: '：保存好你的密码，不要泄露给他人',
                            style: TextStyle(
                              color: normalColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: SystemNavigator.pop,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '退出',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _secondsLeft == 0 ? _handleAcknowledge : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _secondsLeft == 0 ? '我知晓' : '我知晓（${_secondsLeft}s）',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
